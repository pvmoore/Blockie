module blockie.render.ui.StatsUI;

import blockie.render.all;

final class StatsUI {
private:
    @Borrowed VulkanContext context;
    @Borrowed Vulkan vk;
    @Borrowed VkDevice device;
public:
    HistogramUI fpsHistogram;
    HistogramUI frameTimeHistogram;
    HistogramUI updateTimeHistogram;
    MemStatsUI memStats;
    StatusMonitorUI diskMonitor;
    StatusMonitorUI gpuIoMonitor;
    StatusMonitorUI chunksMonitor;

    this(VulkanContext context) {
        this.context = context;
        this.vk = context.vk;
        this.device = context.device;
        this.fpsHistogram = new HistogramUI("FPS", 32, "%.0f");
        this.frameTimeHistogram = new HistogramUI("Frame Time", 32, "%.2f");
        this.updateTimeHistogram = new HistogramUI("Update Time", 16, "%.2f");
        this.memStats = new MemStatsUI();
        this.diskMonitor = new StatusMonitorUI("Disk (MB)");
        this.gpuIoMonitor = new StatusMonitorUI("GPU (MB)");
        this.chunksMonitor = new StatusMonitorUI("Chunks");

        diskMonitor
            .addValue(EventID.STORAGE_READ,  "Read .. ", "%3.1f", "")
            .addValue(EventID.STORAGE_WRITE, "Write .. ", "%3.1f", "")
            .initialise();

        gpuIoMonitor
            .addValue(EventID.GPU_WRITES, "Writes ..... ", "%4.2f", "")
            .addValue(EventID.GPU_VOXELS_USAGE, "Used (vx) .. ", "%4.2f", "")
            .addValue(EventID.GPU_CHUNKS_USAGE, "Used (ch) .. ", "%4.2f", "K")
            .addValue(EventID.CM_CAMERA_MOVE_UPDATE_TIME, "Cam updt ... ", "%4.2f", " ms")
            .addValue(EventID.CM_CHUNK_UPDATE_TIME, "Chk updt ... ", "%4.2f", " ms")
            .initialise();

        chunksMonitor
            .addValue(EventID.CHUNKS_TOTAL, "Total ...... ", "%6.0f", "")
            .addValue(EventID.CHUNKS_ON_GPU, "On GPU ..... ", "%6.0f", "")
            .addValue(EventID.CHUNKS_READY, "Ready ...... ", "%6.0f", "")
            .addValue(EventID.CHUNKS_FLYWEIGHT, "Flyweight .. ", "%6.0f", "")
            .initialise();
    }
    void destroy() {
        // Nothing to destroy
    }
    void update(AbsRenderData renderData) {
        // Nothing to update
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
            //| ImGuiWindowFlags_NoBackground
            //| ImGuiWindowFlags_NoMove;
            ;

        igPushFont(vk.getImguiFont(0));
        igPushStyleVar_Float(ImGuiStyleVar_FrameBorderSize, 1);

        if(igBegin("Stats", null, windowFlags)) {

            fpsHistogram.render();
            frameTimeHistogram.render();
            updateTimeHistogram.render();
            memStats.render();
            diskMonitor.render();
            gpuIoMonitor.render();
            chunksMonitor.render();
        }
        igEnd();

        igPopStyleVar(1);
        igPopFont();
    }
}

