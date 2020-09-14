module blockie.render.gl.GLRenderview;

import blockie.render.all;

final class GLRenderView : RenderView {
protected:
    OpenGL gl;
public:
    this(OpenGL gl) {
        super(gl.windowSize);

        this.gl              = gl;
        this.console         = new GLConsole(gl, renderRect.y);
        this.topBar          = new GLTopBar(gl, this, renderRect.y+1);
        this.bottomBar       = new GLBottomBar(gl, this);
        this.minimap         = new GLMinimap(gl);
        this.computeRenderer = new GLComputeRenderer(gl, this, renderRect);


        this.memMonitor         = new GLMemMonitor(gl);
        this.cpuMonitor         = new GLCpuMonitor(gl);
        this.fpsMonitor         = new GLMonitor(gl, "FPS", null);
        this.frametimeMonitor   = new GLMonitor(gl, "FrameTime", null);
        this.updateTimeMonitor  = new GLMonitor(gl, "UpdateTime", null);
        this.computeTimeMonitor = new GLMonitor(gl, "ComputeTime", "Compute");
        this.diskMonitor        = new GLMonitor(gl, "DiskUsage", "Disk (MB) ");
        this.gpuIoMonitor       = new GLMonitor(gl, "GPUUsage", "GPU (MB)");
        this.chunksMonitor      = new GLMonitor(gl, "ChunksUsage", "Chunks");

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

        glClearColor(0.1, 0, 0, 0);

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);

        // for the skybox
        glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);

        CheckGLErrors();
    }
    @Implements("RenderView")
    override void setWorld(World world) {
        super.setWorld(world);

        computeRenderer.setWorld(world);
    }
protected:
    override void updateScene(AbsRenderData renderData, bool cameraMoved) {
        if(cameraMoved) {

        }
        computeRenderer.update(renderData, cameraMoved);
    }
    override void renderScene(AbsRenderData renderData) {
        glClear(GL_COLOR_BUFFER_BIT);

        computeRenderer.render(renderData);
    }
    override bool isKeyPressed(uint key) {
        return gl.isKeyPressed(key);
    }
    override bool isMouseButtonPressed(uint button) {
        return gl.isMouseButtonPressed(0);
    }
    override float getFps() {
        return gl.FPS();
    }
}

