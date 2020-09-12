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
import blockie.render.BottomBar;
import blockie.render.ChunkManager;
import blockie.render.ComputeRenderer;
import blockie.render.Console;
import blockie.render.EventStatsMonitor;
import blockie.render.MiniMap;
import blockie.render.RenderView;
import blockie.render.TopBar;

version(VULKAN) {
    pragma(msg, "VULKAN");

    import vulkan;

    final class VKRenderData : AbsRenderData {
        Frame frame;

        VkCommandBuffer[] commandBuffers;
        VkSemaphore[] waitSemaphores;
        VPipelineStage[] waitStages;
    }

    import blockie.render.vk.VKBlockie;
    import blockie.render.vk.VKBottomBar;
    import blockie.render.vk.VKComputeRenderer;
    import blockie.render.vk.VKConsole;
    import blockie.render.vk.VKCpuMonitor;
    import blockie.render.vk.VKGPUMemoryManager;
    import blockie.render.vk.VKMemMonitor;
    import blockie.render.vk.VKMonitor;
    import blockie.render.vk.VKMiniMap;
    import blockie.render.vk.VKRenderView;
    import blockie.render.vk.VKTopBar;
}
version(OPENGL) {
    pragma(msg, "OPENGL");

    final class GLRenderData : AbsRenderData {
        ulong frameNumber;
        float seconds;
    }

    import gl;
    import gl.geom : BitmapSprite;
    import derelict.opengl;
    import derelict.glfw3;

    import blockie.render.gl.GLBlockie;
    import blockie.render.gl.GLBottomBar;
    import blockie.render.gl.GLBoxRenderer;
    import blockie.render.gl.GLConsole;
    import blockie.render.gl.GLCPUMonitor;
    import blockie.render.gl.GLComputeRenderer;
    import blockie.render.gl.GLGPUMemoryManager;
    import blockie.render.gl.GLMinimap;
    import blockie.render.gl.GLMemMonitor;
    import blockie.render.gl.GLMonitor;
    import blockie.render.gl.GLRenderview;
    import blockie.render.gl.GLTopBar;
}
