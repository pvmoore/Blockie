module blockie.render.gl.GLRenderview;

import blockie.render.all;

final class GLRenderView : RenderView {
protected:
    OpenGL gl;
    GLComputeRenderer glComputeSceneRenderer;
    SkyBox skybox;
public:
    this(OpenGL gl) {
        super();

        calculateRenderRect(gl.windowSize);

        this.gl = gl;
        this.console      = new GLConsole(gl, renderRect.y);
        this.topBar       = new GLTopBar(gl, this, renderRect.y+1);
        this.bottomBar    = new GLBottomBar(gl, this, );
        this.minimap      = new GLMinimap(gl);
        this.frameTiming  = new Timing(10,3);
        this.updateTiming = new Timing(10,1);

        this.glComputeSceneRenderer = new GLComputeRenderer(gl, this, renderRect);

        this.skybox = new SkyBox(gl, "/pvmoore/_assets/images/skyboxes/skybox1");

        this.memMonitor  = new GLMemMonitor(gl);
        this.cpuMonitor = new GLCpuMonitor(gl);
        this.fpsMonitor = new GLMonitor(gl, "FPS", null);
        this.frametimeMonitor = new GLMonitor(gl, "FrameTime", null);
        this.updateTimeMonitor = new GLMonitor(gl, "UpdateTime", null);
        this.computeTimeMonitor = new GLMonitor(gl, "ComputeTime", "Compute");
        this.diskMonitor = new GLMonitor(gl, "DiskUsage", "Disk (MB) ");
        this.gpuIoMonitor = new GLMonitor(gl, "GPUUsage", "GPU (MB)");
        this.chunksMonitor = new GLMonitor(gl, "ChunksUsage", "Chunks");

        initialiseMonitors();
    }
    override void setWorld(World world) {
        super.setWorld(world);

        glComputeSceneRenderer.setWorld(world);
        skybox.setVP(world.camera);
    }
    @Implements("RenderView")
    override void destroy() {
        super.destroy();

        skybox.destroy();
        glComputeSceneRenderer.destroy();
    }
    @Implements("RenderView")
    override void enteringView() {
        super.enteringView();

        glClearColor(0.1, 0, 0, 0);

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);

        // for the skybox
        glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);

        CheckGLErrors();
    }
protected:
    override void doRender(ulong frameNumber, float seconds, float perSecond) {
        glClear(GL_COLOR_BUFFER_BIT);

        skybox.render();
        glComputeSceneRenderer.render();
    }
    override bool isKeyPressed(uint key) {
        return gl.isKeyPressed(key);
    }
    override bool isMouseButtonPressed(uint button) {
        return gl.isMouseButtonPressed(0);
    }
    override void afterUpdate(bool cameraMoved, float perSecond) {
        if(cameraMoved) {
            skybox.setVP(world.camera);
        }
        glComputeSceneRenderer.afterUpdate(cameraMoved);
    }
    override void renderOptionsChanged() {
        topBar.renderOptionsChanged();
        glComputeSceneRenderer.renderOptionsChanged();
    }
    override float2 getWindowSize() {
        return gl.windowSize;
    }
    override float getFps() {
        return gl.FPS();
    }
}

