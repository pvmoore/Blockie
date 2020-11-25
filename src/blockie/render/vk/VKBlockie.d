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
        MARCH_VOXEL_BUFFER     = "VOXELS".as!BufID,
        MARCH_CHUNK_BUFFER     = "CHUNKS".as!BufID
    }

    this() {
        this.renderData = new VKRenderData();
        renderData.commandBuffers.reserve(8);
        renderData.waitSemaphores.reserve(8);
        renderData.waitStages.reserve(8);
    }
    @Implements("Blockie")
    override void initialise() {
        super.initialise();

        WindowProperties wprops = {
            width:        WIDTH,
            height:       HEIGHT,
            fullscreen:   false,
            vsync:        false,
            title:        title,
            icon:         "/pvmoore/_assets/icons/3dshapes.png",
            showWindow:   false,
            frameBuffers: NUM_FRAME_BUFFERS
        };
        VulkanProperties vprops = {
            appName: "Blockie"
        };

        vprops.features.samplerAnisotropy = VK_TRUE;

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
    @Implements("IVulkanApplication")
    void keyPress(uint keyCode, uint scanCode, KeyAction action, uint mods) {
        renderView.keyPress(keyCode, KeyAction.PRESS, mods);
    }
    @Implements("IVulkanApplication")
    void mouseButton(MouseButton button, float x, float y, bool down, uint mods) {

    }
    @Implements("IVulkanApplication")
    void mouseMoved(float x, float y) {

    }
    @Implements("IVulkanApplication")
    void mouseWheel(float xdelta, float ydelta, float x, float y) {

    }
    @Implements("IVulkanApplication")
    void deviceReady(VkDevice device, PerFrameResource[] frameResources) {
        this.log("deviceReady");
        this.device = device;

        createContext();

        this.renderView = new VKRenderView(context);
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
        renderData.waitStages[0]     = VPipelineStage.COLOR_ATTACHMENT_OUTPUT;

        // Outside render pass
        view.update(renderData);

        view.as!VKRenderView.beforeRenderPass(renderData);

        // Inside render pass: initialLayout = VImageLayout.UNDEFINED
        b.beginRenderPass(
            context.renderPass,
            res.frameBuffer,
            toVkRect2D(0,0, vk.windowSize.toVkExtent2D),
            [ clearColour(0.5f,0,0,1) ],
            VSubpassContents.INLINE //VSubpassContents.SECONDARY_COMMAND_BUFFERS
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

        auto storageSize =
            Blockie.VOXEL_BUFFER_SIZE
            + Blockie.CHUNK_BUFFER_SIZE*NUM_FRAME_BUFFERS
            + 8*NUM_FRAME_BUFFERS.MB
            + 4.MB;

        auto stagingSize =
            storageSize
            + 256.MB
            + 5.MB;

        this.log("Storage size = %s", storageSize);
        this.log("Staging size = %s", stagingSize);

        this.context = new VulkanContext(vk)
            .withMemory(MemID.LOCAL, mem.allocStdDeviceLocal("Blockie_Local", storageSize + 256.MB))
            .withMemory(MemID.STAGING, mem.allocStdStagingUpload("Blockie_Staging", stagingSize));

        context.withBuffer(MemID.LOCAL, BufID.VERTEX, VBufferUsage.VERTEX | VBufferUsage.TRANSFER_DST, 16.MB)
               .withBuffer(MemID.LOCAL, BufID.INDEX, VBufferUsage.INDEX | VBufferUsage.TRANSFER_DST, 16.MB)
               .withBuffer(MemID.LOCAL, BufID.UNIFORM, VBufferUsage.UNIFORM | VBufferUsage.TRANSFER_DST, 1.MB)
               .withBuffer(MemID.LOCAL, BufID.STORAGE, VBufferUsage.STORAGE | VBufferUsage.TRANSFER_DST, 8*NUM_FRAME_BUFFERS.MB)

               .withBuffer(MemID.LOCAL, MARCH_VOXEL_BUFFER, VBufferUsage.STORAGE | VBufferUsage.TRANSFER_DST, Blockie.VOXEL_BUFFER_SIZE)
               .withBuffer(MemID.LOCAL, MARCH_CHUNK_BUFFER, VBufferUsage.STORAGE | VBufferUsage.TRANSFER_DST, Blockie.CHUNK_BUFFER_SIZE*NUM_FRAME_BUFFERS)

               .withBuffer(MemID.STAGING, BufID.STAGING, VBufferUsage.TRANSFER_SRC, stagingSize - 5.MB);

        context.withRenderPass(renderPass)
               .withFonts("resources/fonts/")
               .withImages("resources/images")
               .withShaderCompiler("shaders/", "resources/shaders/");

        this.log("%s", context);
    }
    void createRenderPass(VkDevice device) {
        this.log("Creating render pass");

        // Create render pass without clearing the back buffer
        auto colorAttachment = attachmentDescription(
            vk.swapchain.colorFormat,
            (info) {
                info.loadOp = VAttachmentLoadOp.DONT_CARE;
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