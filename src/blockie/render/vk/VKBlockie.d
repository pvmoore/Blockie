module blockie.render.vk.VKBlockie;

import blockie.render.all;

final class VKBlockie : Blockie, IVulkanApplication {
private:
    enum NUM_FRAME_BUFFERS = 3;
    Vulkan vk;
    VkDevice device;
    VulkanContext context;
    VkRenderPass renderPass;
    VKRenderData renderData;
public:
    enum : BufID {
        MARCH_VOXEL_BUFFER = "VOXELS".as!BufID,
        MARCH_CHUNK_BUFFER = "CHUNKS".as!BufID
    }

    this() {
        this.renderData = new VKRenderData();
    }
    @Implements("Blockie")
    override void initialise() {
        super.initialise();

        ImguiOptions imguiOptions = {
            enabled: true,
            configFlags:
                ImGuiConfigFlags_NoMouseCursorChange |
                ImGuiConfigFlags_DockingEnable |
                ImGuiConfigFlags_ViewportsEnable,
            fontPaths: [
                "/pvmoore/_assets/fonts/JetBrainsMono-Bold.ttf"
            ],
            fontSizes: [
                18
            ]
        };

        WindowProperties wprops = {
            width:        WIDTH,
            height:       HEIGHT,
            fullscreen:   false,
            vsync:        false,
            title:        title,
            icon:         "resources/images/logo.png",
            showWindow:   false,
            frameBuffers: NUM_FRAME_BUFFERS,
            titleBarFps:  true
        };
        // Vulkan 1.3
        VulkanProperties vprops = {
            appName: "Blockie",
            apiVersion: vulkanVersion(1,3,0),
            imgui: imguiOptions,
            shaderSrcDirectories: ["shaders/", "/pvmoore/d/libs/vulkan/shaders/"],
            shaderDestDirectory: "resources/shaders/",
            shaderSpirvVersion: "1.6"
        };

        vprops.enableGpuValidation = false;
        vprops.enableShaderPrintf = false;

		this.vk = new Vulkan(this, wprops, vprops);

        // Will call deviceReady
        vk.initialise();

        import std : fromStringz, format;
        import core.cpuid: processor;
        string gpuName = cast(string)vk.properties.deviceName.ptr.fromStringz;
        vk.setWindowTitle("%s :: Vulkan (%sx%s) :: %s, %s".format(title, WIDTH, HEIGHT, processor().strip(), gpuName));

        initWorld(vk.windowSize().to!float);

        vk.showWindow();
    }
    @Implements("Blockie, IVulkanApplication")
    override void destroy() {
        if(device) {
	        vkDeviceWaitIdle(device);
        }

        super.destroy();

	    if(device) {
            if(context) context.dumpMemory();
	        if(renderPass) device.destroyRenderPass(renderPass);
            if(context) context.destroy();
	    }
        if(vk) {
            vk.destroy();
            vk = null;
        }
    }
    @Implements("Blockie, IVulkanApplication")
    override void run() {
        vk.mainLoop();
    }


    // @Implements("IVulkanApplication")
    // void keyPress(uint keyCode, uint scanCode, KeyAction action, uint mods) {
    //     renderView.keyPress(keyCode, KeyAction.PRESS, mods);
    // }
    // @Implements("IVulkanApplication")
    // void mouseButton(MouseButton button, float x, float y, bool down, uint mods) {

    // }
    // @Implements("IVulkanApplication")
    // void mouseMoved(float x, float y) {

    // }
    // @Implements("IVulkanApplication")
    // void mouseWheel(float xdelta, float ydelta, float x, float y) {

    // }


    @Implements("IVulkanApplication")
    void deviceReady(VkDevice device, PerFrameResource[] frameResources) {
        this.log("deviceReady");
        this.device = device;

        createContext();

        vk.addWindowEventListener(new class WindowEventListener {
            override void keyPress(uint keyCode, uint scanCode, KeyAction action, uint mods) {
                renderView.keyPress(keyCode, action==KeyAction.PRESS, mods);
            }
        });

        this.renderView = new VKRenderView(context);
    }
    @Implements("IVulkanApplication")
    void selectFeatures(DeviceFeatures features) {

    }
    @Implements("IVulkanApplication")
    void selectQueueFamilies(QueueManager queueManager) {
        // Use the default queue families chosen by our Vulkan app
    }
    @Implements("IVulkanApplication")
    VkRenderPass getRenderPass(VkDevice device) {
        createRenderPass(device);
        return renderPass;
    }
    @Implements("IVulkanApplication")
    void render(Frame frame) {
        if(nextView) {
            if(view) view.exitingView();
            view = nextView;
            view.enteringView();
            nextView = null;
        }
        if(!view) return;

        // Start issuing commands
        auto res = frame.resource;
        auto b = res.adhocCB;
        b.beginOneTimeSubmit();

        renderData.frame = frame;
        renderData.perSecond = frame.perSecond;
        renderData.commandBuffers.length = 1;
        renderData.waitSemaphores.length = 1;
        renderData.waitStages.length     = 1;

        // Standard command buffer and wait semaphores
        renderData.commandBuffers[0] = b;
        renderData.waitSemaphores[0] = res.imageAvailable;
        renderData.waitStages[0]     = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

        // Outside render pass
        view.update(renderData);

        view.as!VKRenderView.beforeRenderPass(renderData);

        // Inside render pass: initialLayout = VImageLayout.UNDEFINED
        b.beginRenderPass(
            context.renderPass,
            res.frameBuffer,
            toVkRect2D(0,0, vk.windowSize.toVkExtent2D),
            [],         // no clear values required because loadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
            VK_SUBPASS_CONTENTS_INLINE
        );

        view.render(renderData);

        b.endRenderPass();
        // After render pass: finalLayout = VImageLayout.PRESENT_SRC_KHR

        view.as!VKRenderView.afterRenderPass(renderData);

        b.end();

        auto signalSemaphores = [
            res.renderFinished
        ];

        /// Submit our render buffer
        context.vk.getGraphicsQueue().submit(
            renderData.commandBuffers,
            renderData.waitSemaphores,
            renderData.waitStages,
            signalSemaphores,
            res.fence
        );
    }
private:
    void createContext() {
        auto mem = new MemoryAllocator(vk);

        auto storageSize = 8*WIDTH*HEIGHT*NUM_FRAME_BUFFERS;

        auto deviceLocalSize =
            Blockie.VOXEL_BUFFER_SIZE
            + Blockie.CHUNK_BUFFER_SIZE*NUM_FRAME_BUFFERS
            + storageSize
            + 256.MB    // ?
            + 4.MB;     // for target image

        auto stagingSize =
            deviceLocalSize
            + 256.MB    // ?
            + 5.MB;     // ?

        this.log("Device local size ........ %.2f MB", deviceLocalSize / MB(1).as!float);
        this.log("Storage buffer size ...... %.2f MB", storageSize / MB(1).as!float);
        this.log("Voxel buffer size ........ %.2f MB", VOXEL_BUFFER_SIZE / MB(1).as!float);
        this.log("Chunk index buffer size .. %.2f MB", CHUNK_BUFFER_SIZE / MB(1).as!float);
        this.log("Staging buffer size ...... %.2f MB", stagingSize / MB(1).as!float);

        this.context = new VulkanContext(vk)
            .withMemory(MemID.LOCAL, mem.allocStdDeviceLocal("Blockie_Local", deviceLocalSize))
            .withMemory(MemID.STAGING, mem.allocStdStagingUpload("Blockie_Staging", stagingSize));

        context.withBuffer(MemID.LOCAL, BufID.VERTEX, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, 16.MB)
               .withBuffer(MemID.LOCAL, BufID.INDEX, VK_BUFFER_USAGE_INDEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, 16.MB)
               .withBuffer(MemID.LOCAL, BufID.UNIFORM, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, 1.MB)
               .withBuffer(MemID.LOCAL, BufID.STORAGE, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, storageSize)

               .withBuffer(MemID.LOCAL, MARCH_VOXEL_BUFFER, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, Blockie.VOXEL_BUFFER_SIZE)
               .withBuffer(MemID.LOCAL, MARCH_CHUNK_BUFFER, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, Blockie.CHUNK_BUFFER_SIZE*NUM_FRAME_BUFFERS)

               .withBuffer(MemID.STAGING, BufID.STAGING, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, stagingSize - 5.MB);

        context.withRenderPass(renderPass)
               .withFonts("resources/fonts/")
               .withImages("resources/images");

        this.log("%s", context);
    }
    void createRenderPass(VkDevice device) {
        this.log("Creating render pass");

        // Create render pass without clearing the back buffer
        auto colorAttachment = attachmentDescription(
            vk.swapchain.colorFormat,
            (info) {
                info.loadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
            });

        // Create standard render pass
        //auto colorAttachment    = attachmentDescription(vk.swapchain.colorFormat);

        auto colorAttachmentRef = attachmentReference(0);

        auto subpass = subpassDescription((info) {
            info.colorAttachmentCount = 1;
            info.pColorAttachments    = &colorAttachmentRef;
        });

        this.renderPass = .createRenderPass(
            device,
            [colorAttachment],
            [subpass],
            subpassDependency2()
        );
    }
}
