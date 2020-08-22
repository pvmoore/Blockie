module blockie.render.all;

public:

interface IView {
    void destroy();
    void enteringView();
    void exitingView();
    bool isReady();
    void update(float timeDelta);
    void render(ulong frameNumber, float seconds, float perSecond);
}
interface IRenderer {
    void destroy();
    void render();
    void afterUpdate(bool cameraMoved);
    void setWorld(World w);
}
interface IMonitor {
    IMonitor initialise();
    void destroy();
    IMonitor colour(RGBA c);
    IMonitor formatting(string fmt);
    IMonitor move(int2 pos);
    void update(uint index, double value);
    void render();
}

import blockie.globals;

import blockie.render.blockie;
import blockie.render.BottomBar;
import blockie.render.Console;
import blockie.render.EventStatsMonitor;
import blockie.render.MiniMap;
import blockie.render.RenderView;
import blockie.render.TopBar;

version(VULKAN) {
    pragma(msg, "VULKAN");

    import vulkan;

    import blockie.render.vk.VKComputeRenderer;

}
version(OPENGL) {
    pragma(msg, "OPENGL");

    import gl;
    import gl.geom : BitmapSprite;
    import derelict.opengl;
    import derelict.glfw3;

    import blockie.render.ChunkManager;

    import blockie.render.gl.GLBottomBar;
    import blockie.render.gl.GLBoxRenderer;
    import blockie.render.gl.GLConsole;
    import blockie.render.gl.GLCPUMonitor;
    import blockie.render.gl.GLComputeRenderer;
    import blockie.render.gl.GLMinimap;
    import blockie.render.gl.GLMemMonitor;
    import blockie.render.gl.GLMonitor;
    import blockie.render.gl.GLRenderview;
    import blockie.render.gl.GLTopBar;
}
