module blockie.render.all;

public:

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
    long write(T[] data);
    void free(ulong offset, ulong size);
}

import blockie.globals;

import blockie.render.Blockie;
import blockie.render.ChunkManager;
import blockie.render.ComputeRenderer;
import blockie.render.RenderView;

import vulkan;

final class VKRenderData : AbsRenderData {
    Frame frame;

    VkCommandBuffer[] commandBuffers;
    VkSemaphore[] waitSemaphores;
    VkPipelineStageFlags[] waitStages;
}

import blockie.render.ui.StatsUI;
import blockie.render.ui.BottomBar;
import blockie.render.ui.HistogramUI;
import blockie.render.ui.TopBar;

import blockie.render.ui.Console;
import blockie.render.ui.MemStatsUI;
import blockie.render.ui.StatsMonitorUI;
import blockie.render.ui.VKTopBar;
import blockie.render.ui.VKBottomBar;
import blockie.render.ui.VKConsole;

import blockie.render.legacy.EventStatsMonitor;
import blockie.render.legacy.VKCpuMonitor;
import blockie.render.legacy.VKMonitor;
import blockie.render.legacy.MiniMap;
import blockie.render.legacy.VKMiniMap;

import blockie.render.vk.VKBlockie;
import blockie.render.vk.VKComputeRenderer;
import blockie.render.vk.VKGPUMemoryManager;
import blockie.render.vk.VKRenderView;