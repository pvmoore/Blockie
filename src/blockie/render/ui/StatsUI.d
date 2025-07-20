module blockie.render.ui.StatsUI;

import blockie.render.all;

final class StatsUI {
private:
    @Borrowed VulkanContext context;
    @Borrowed Vulkan vk;
    @Borrowed VkDevice device;

    HistogramUI fpsHistogram;
    HistogramUI frameTimeHistogram;
    HistogramUI updateTimeHistogram;
    HistogramUI computeTimeHistogram;
    EventMonitorUI diskMonitor;
    EventMonitorUI gpuIoMonitor;
    EventMonitorUI chunksMonitor;
    EventMonitorUI memMonitor;
public:

    this(VulkanContext context, Timing frameTiming, Timing updateTiming) {
        this.context = context;
        this.vk = context.vk;
        this.device = context.device;

        this.fpsHistogram = new HistogramUI("FPS", 32, "%.0f", new FpsStatProvider(vk)).setOpen();
        this.frameTimeHistogram = new HistogramUI("Frame Time", 32, "%.2f", new TimingStatProvider(frameTiming, 2));
        this.computeTimeHistogram = new HistogramUI("Compute Time", 32, "%.2f", new EventStatProvider("ComputeStats").addEvent(EventID.COMPUTE_TIME).initialise());
        this.updateTimeHistogram = new HistogramUI("Update Time", 16, "%.2f", new TimingStatProvider(updateTiming, 0));

        this.memMonitor = new EventMonitorUI("GC Memory");
        this.diskMonitor = new EventMonitorUI("Disk");
        this.gpuIoMonitor = new EventMonitorUI("GPU");
        this.chunksMonitor = new EventMonitorUI("Chunks");

        memMonitor
            .addValue(EventID.MEM_USED,                  "Used ............. ", "%.0f", "")
            .addValue(EventID.MEM_RESERVED,              "Reserved ......... ", "%.0f", "")
            .addValue(EventID.MEM_TOTAL_COLLECTIONS,     "# Collections .... ", "%.0f", "")
            .addValue(EventID.MEM_TOTAL_COLLECTION_TIME, "Collection time .. ", "%.0f", " ms")
            .initialise();

        diskMonitor
            .addValue(EventID.STORAGE_READ,  "Read ... ", "%.2f", " MB")
            .addValue(EventID.STORAGE_WRITE, "Write .. ", "%.2f", " MB")
            .initialise();

        gpuIoMonitor
            .addValue(EventID.GPU_WRITES,                 "Writes ..... ", "%.2f", " MB")
            .addValue(EventID.GPU_VOXELS_USAGE,           "Used (vx) .. ", "%.2f", " MB")
            .addValue(EventID.GPU_CHUNKS_USAGE,           "Used (ch) .. ", "%.2f", " K")
            .addValue(EventID.CM_CAMERA_MOVE_UPDATE_TIME, "Cam updt ... ", "%.2f", " ms")
            .addValue(EventID.CM_CHUNK_UPDATE_TIME,       "Chk updt ... ", "%.2f", " ms")
            .initialise();

        chunksMonitor
            .addValue(EventID.CHUNKS_TOTAL,     "Total ...... ", "%.0f", "")
            .addValue(EventID.CHUNKS_ON_GPU,    "On GPU ..... ", "%.0f", "")
            .addValue(EventID.CHUNKS_READY,     "Ready ...... ", "%.0f", "")
            .addValue(EventID.CHUNKS_FLYWEIGHT, "Flyweight .. ", "%.0f", "")
            .initialise();
    }
    void destroy() {
        // Nothing to destroy
    }
    void update() {
        fpsHistogram.tick();
        frameTimeHistogram.tick();
        updateTimeHistogram.tick();
        computeTimeHistogram.tick();

        memMonitor.tick();
        diskMonitor.tick();
        gpuIoMonitor.tick();
        chunksMonitor.tick();
    }
    void renderFrame(AbsRenderData absRenderData) {
        if(!vk.vprops.imgui.enabled) return;

        VKRenderData renderData = absRenderData.as!VKRenderData;
        Frame frame = renderData.frame;

        vk.imguiRenderStart(frame);

        renderFrame(frame);

        vk.imguiRenderEnd(frame);
    }
private:
    void renderFrame(Frame frame) {

        igSetNextWindowPos(ImVec2(12, 30), ImGuiCond_Once, ImVec2(0.0, 0.0));
        //igSetNextWindowSize(ImVec2(200, 30), ImGuiCond_Once);

        auto windowFlags = ImGuiWindowFlags_None
            | ImGuiWindowFlags_NoSavedSettings
            //| ImGuiWindowFlags_NoTitleBar
            //| ImGuiWindowFlags_NoCollapse
            | ImGuiWindowFlags_NoResize
            | ImGuiWindowFlags_NoBackground
            //| ImGuiWindowFlags_NoMove;
            ;

        igPushFont(vk.getImguiFont(0), 0);
        igPushStyleVar_Float(ImGuiStyleVar_FrameBorderSize, 1);

        if(igBegin("Stats", null, windowFlags)) {

            fpsHistogram.render();
            computeTimeHistogram.render();
            frameTimeHistogram.render();
            updateTimeHistogram.render();

            memMonitor.render();
            diskMonitor.render();
            gpuIoMonitor.render();
            chunksMonitor.render();

        }
        igEnd();

        igPopStyleVar(1);
        igPopFont();
    }
}

