module blockie.render.vk.VKRenderView;

import blockie.render.all;

final class VKRenderView : RenderView {
public:
    this(VulkanContext context) {
        super(context.vk.windowSize().to!float);

        this.vk              = context.vk;
        this.context         = context;
        this.topBar          = new TopBar(context, this, renderRect.y+1);

        this.bottomBar       = new VKBottomBar(context, this);
        this.computeRenderer = new VKComputeRenderer(context, this, renderRect);

        statsUI = new StatsUI(context, frameTiming, updateTiming);
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
    int seconds;
    int seconds16;
    override void updateScene(AbsRenderData absRenderData, bool cameraMoved) {
        auto renderData = absRenderData.as!VKRenderData;
        Frame frame = renderData.frame;

        if(cameraMoved) {

        }

        auto time = frame.seconds.as!int;
        if(time > seconds) {
            // tick per second
            seconds = time;
            takeSnapshotPerSecond();
        }

        time = (frame.seconds*16).as!int;
        if(time > seconds16) {
            // tick (16 per second)
            seconds16 = time;

            takeSnapshotPer16thsOfSecond();
        }

        computeRenderer.update(absRenderData, cameraMoved);
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
        return vk.getFPSSnapshot();
    }
private:
    @Borrowed Vulkan vk;
    @Borrowed VulkanContext context;
    
    void takeSnapshotPerSecond() {
        import core.memory : GC;
        uint free = (GC.stats.freeSize / (1024*1024)).to!uint;
        uint used = (GC.stats.usedSize / (1024*1024)).to!uint;

        uint reserved = (free+used);

        auto numCollections = GC.profileStats.numCollections.to!uint;
        auto totalCollectionTime = GC.profileStats.totalCollectionTime.total!"msecs";

        getEvents().fire(EventID.MEM_USED, used.to!double);
        getEvents().fire(EventID.MEM_RESERVED, reserved.to!double);
        getEvents().fire(EventID.MEM_TOTAL_COLLECTIONS, numCollections.to!double);
        getEvents().fire(EventID.MEM_TOTAL_COLLECTION_TIME, totalCollectionTime.to!double);
    }
    void takeSnapshotPer16thsOfSecond() {
        statsUI.update();
    }
}
