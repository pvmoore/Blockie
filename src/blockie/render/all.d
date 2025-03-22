module blockie.render.all;

public:

import blockie.globals;

import blockie.render.Blockie;
import blockie.render.ChunkManager;
import blockie.render.ComputeRenderer;
import blockie.render.RenderView;
import blockie.render.stat_providers;

import blockie.render.ui.StatsUI;
import blockie.render.ui.BottomBar;
import blockie.render.ui.HistogramUI;
import blockie.render.ui.TopBar;

import blockie.render.ui.EventMonitorUI;
import blockie.render.ui.VKBottomBar;

import blockie.render.vk.VKBlockie;
import blockie.render.vk.VKComputeRenderer;
import blockie.render.vk.VKGPUMemoryManager;
import blockie.render.vk.VKRenderView;

import vulkan;

abstract class AbsRenderData {
    double perSecond;
}
interface IView {
    void destroy();
    void enteringView();
    void exitingView();
    bool isReady();
    void update(AbsRenderData renderData);
    void render(AbsRenderData renderData);
}
interface IRenderer {
    void destroy();
    void update(AbsRenderData renderData, bool cameraMoved);
    void render(AbsRenderData renderData);
    void setWorld(World w);
    void renderOptionsChanged();
}
interface IMonitor {
    IMonitor initialise();
    void destroy();
    IMonitor colour(RGBA c);
    IMonitor formatting(string fmt);
    IMonitor move(int2 pos);
    void updateValue(uint index, double value);
    void update(AbsRenderData renderData);
    void render(AbsRenderData renderData);
}
interface IGPUMemoryManager(T) {
    ulong getNumBytesUsed();
    void bind();
    ulong write(T[] data);
    void free(ulong offset, ulong size);
}

final class VKRenderData : AbsRenderData {
    Frame frame;

    VkCommandBuffer[] commandBuffers;
    VkSemaphore[] waitSemaphores;
    VkPipelineStageFlags[] waitStages;
}
