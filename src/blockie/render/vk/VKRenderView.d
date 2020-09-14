module blockie.render.vk.VKRenderView;

import blockie.render.all;

final class VKRenderView : RenderView {
private:
    @Borrowed Vulkan vk;
    @Borrowed VulkanContext context;
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

        }
        computeRenderer.update(renderData, cameraMoved);
    }
    override void renderScene(AbsRenderData renderData) {
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