module blockie.render.vk.VKBlockie;

import blockie.render.all;

final class VKBlockie : Blockie, IVulkanApplication {
private:
    Vulkan vk;
    VkDevice device;
    VulkanContext context;
    VkRenderPass renderPass;
public:
    override void initialise() {
        super.initialise();

        WindowProperties wprops = {
            width: 1200,
            height: 800,
            fullscreen: false,
            vsync: false,
            title: title,
            icon: "/pvmoore/_assets/icons/3dshapes.png",
            showWindow: false,
            frameBuffers: 3
        };
        VulkanProperties vprops = {
            appName: "Blockie"
        };

		this.vk = new Vulkan(this, wprops, vprops);

        // Will call deviceReady
        vk.initialise();

        import std : fromStringz, format;
        import core.cpuid: processor;
        string gpuName = cast(string)vk.properties.deviceName.ptr.fromStringz;
        vk.setWindowTitle("%s :: Vulkan :: %s, %s".format(title, processor().strip(), gpuName));

        initWorld(vk.windowSize());

        vk.showWindow();
    }
    override void destroy() {
        super.destroy();

        if(!vk) return;
	    if(device) {
	        vkDeviceWaitIdle(device);

            if(context) context.dumpMemory();
	        if(renderPass) device.destroyRenderPass(renderPass);
            if(context) context.destroy();
	    }
		vk.destroy();
        vk = null;
    }
    override void run() {
        vk.mainLoop();
    }
    void keyPress(uint keyCode, uint scanCode, KeyAction action, uint mods) {}
    void mouseButton(MouseButton button, float x, float y, bool down, uint mods) {}
    void mouseMoved(float x, float y) {}
    void mouseWheel(float xdelta, float ydelta, float x, float y) {}

    void deviceReady(VkDevice device, PerFrameResource[] frameResources) {

        //this.renderView = new VKRenderView(context);
    }
    void selectQueueFamilies(QueueManager queueManager) {

    }
    VkRenderPass getRenderPass(VkDevice device) {
        this.log("Creating render pass");
        auto colorAttachment    = attachmentDescription(vk.swapchain.colorFormat);
        auto colorAttachmentRef = attachmentReference(0);

        auto subpass = subpassDescription((info) {
            info.colorAttachmentCount = 1;
            info.pColorAttachments    = &colorAttachmentRef;
        });

        auto dependency = subpassDependency();

        renderPass = .createRenderPass(
            device,
            [colorAttachment],
            [subpass],
            subpassDependency2()//[dependency]
        );
    }
    void render(FrameInfo frame, PerFrameResource res) {

    }
private:

}