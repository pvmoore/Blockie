module blockie.render.vk.VKRenderView;

import blockie.render.all;

final class VKRenderView : RenderView {
private:
    @Borrowed Vulkan vk;
    @Borrowed VulkanContext context;
    @Borrowed ImageMeta cubeMap;
    SkyBox skybox;
public:
    this(VulkanContext context) {
        super(context.vk.windowSize().to!float);

        this.vk              = context.vk;
        this.context         = context;
        this.console         = new VKConsole(context, renderRect.y);
        this.topBar          = new VKTopBar(context, this, renderRect.y+1);

        this.bottomBar       = new VKBottomBar(context, this);
        this.minimap         = new VKMiniMap(context);
        this.computeRenderer = new VKComputeRenderer(context, this, renderRect);

        this.cubeMap = context.images().getCubemap("skybox", "png");
        this.skybox  = new SkyBox(context, cubeMap);

        this.memMonitor         = new VKMemMonitor(context);
        this.cpuMonitor         = new VKCpuMonitor(context);
        this.fpsMonitor         = new VKMonitor(context, "FPS", null);
        this.frametimeMonitor   = new VKMonitor(context, "FrameTime", null);
        this.updateTimeMonitor  = new VKMonitor(context, "UpdateTime", null);
        this.computeTimeMonitor = new VKMonitor(context, "ComputeTime", "Compute");
        this.diskMonitor        = new VKMonitor(context, "DiskUsage", "Disk (MB) ");
        this.gpuIoMonitor       = new VKMonitor(context, "GPUUsage", "GPU (MB)");
        this.chunksMonitor      = new VKMonitor(context, "ChunksUsage", "Chunks");

        initialiseMonitors();
    }
    @Implements("RenderView")
    override void destroy() {
        super.destroy();

        if(skybox) skybox.destroy();
        if(computeRenderer) computeRenderer.destroy();
    }
    @Implements("RenderView")
    override void enteringView() {
        super.enteringView();

    }
    @Implements("RenderView")
    override void exitingView() {
        super.exitingView();
    }
    @Implements("RenderView")
    override void setWorld(World world) {
        super.setWorld(world);

        computeRenderer.setWorld(world);
        skybox.camera(world.camera);
    }
    void beforeRenderPass(VKRenderData renderData) {
        computeRenderer.as!VKComputeRenderer.beforeRenderPass(renderData);
    }
    void afterRenderPass(VKRenderData renderData) {
        computeRenderer.as!VKComputeRenderer.afterRenderPass(renderData);
    }
protected:
    override void updateScene(AbsRenderData renderData, bool cameraMoved) {
        if(cameraMoved) {
            skybox.camera(world.camera);
        }
        computeRenderer.update(renderData, cameraMoved);
        skybox.beforeRenderPass(renderData.as!VKRenderData.frame);
    }
    override void renderScene(AbsRenderData renderData) {

        skybox.insideRenderPass(renderData.as!VKRenderData.frame);
        computeRenderer.render(renderData);
    }
    override bool isKeyPressed(uint key) {
        return vk.isKeyPressed(key);
    }
    override bool isMouseButtonPressed(uint button) {
        return vk.isMouseButtonPressed(0);
    }
    override float getFps() {
        return vk.getFPS();
    }
}