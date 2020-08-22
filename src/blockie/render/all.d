module blockie.render.all;

public:

import blockie.globals;

import blockie.render.blockie;
import blockie.render.iview;
import blockie.render.irenderer;

import blockie.render.EventStatsMonitor;

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
    import blockie.render.gl.box_renderer;
    import blockie.render.gl.GLConsole;
    import blockie.render.gl.GLCPUMonitor;
    import blockie.render.gl.GLComputeRenderer;
    import blockie.render.gl.GLMinimap;
    import blockie.render.gl.GLMemMonitor;
    import blockie.render.gl.GLMonitor;
    import blockie.render.gl.GLRenderview;
    import blockie.render.gl.GLTopBar;
}
