module blockie.render.gl.GLRenderview;

import blockie.render.all;

final class GLRenderView : RenderView {
protected:
    OpenGL gl;
    GLComputeRenderer glComputeSceneRenderer;
    SkyBox skybox;
    GLConsole console;
    GLTopBar topBar;
    GLBottomBar bottomBar;
    GLMinimap minimap;
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

        const Y = 22;

        this.memMonitor  = new GLMemMonitor(gl)
            .initialise()
            .move(int2(gl.windowSize.width.as!int-180, Y+16*6));

        this.cpuMonitor = new GLCpuMonitor(gl)
            .initialise()
            .move(int2(gl.windowSize.width.as!int-180, Y+16*23));

        this.fpsMonitor = new GLMonitor(gl, "FPS", null)
            .colour(WHITE*1.1)
            .formatting("4.2f")
            .addValue(EventID.NONE, "FPS ....... ")
            .initialise()
            .move(int2(cast(int)gl.windowSize.width-180, Y));

        this.frametimeMonitor = new GLMonitor(gl, "FrameTime", null)
            .colour(WHITE*0.92)
            .formatting("4.2f")
            .addValue(EventID.NONE, "Frame ..... ", "ms")
            .initialise()
            .move(int2(cast(int)gl.windowSize.width-180, Y+16*1));

        this.updateTimeMonitor = new GLMonitor(gl, "UpdateTime", null)
            .colour(WHITE*0.92)
            .formatting("4.2f")
            .addValue(EventID.NONE, "Update .... ", "ms")
            .initialise()
            .move(int2(cast(int)gl.windowSize.width-180, Y+16*2));

        this.computeTimeMonitor = new GLMonitor(gl, "ComputeTime", "Compute")
            .colour(WHITE*0.92)
            .formatting("5.2f")
            .addValue(EventID.COMPUTE_RENDER_TIME, "Render ....", "ms")
            .addValue(EventID.COMPUTE_TIME, "Compute ...", "ms")
            .initialise()
            .move(int2(cast(int)gl.windowSize.width-180, Y+16*3));

        this.diskMonitor = new GLMonitor(gl, "DiskUsage", "Disk (MB) ")
            .colour(WHITE*0.92)
            .formatting("3.1f")
            .addValue(EventID.STORAGE_READ,  "Read ... ", "")
            .addValue(EventID.STORAGE_WRITE, "Write .. ", "")
            .initialise()
            .move(int2(cast(int)gl.windowSize.width-180, Y+16*9));

        this.gpuIoMonitor = new GLMonitor(gl, "GPUUsage", "GPU (MB)")
            .colour(WHITE*0.92)
            .formatting("4.2f")
            .addValue(EventID.GPU_WRITES, "Writes ..... ")
            .addValue(EventID.GPU_VOXELS_USAGE, "Used (vx) .. ")
            .addValue(EventID.GPU_CHUNKS_USAGE, "Used (ch) .. ", "K")
            .addValue(EventID.CM_CAMERA_MOVE_UPDATE_TIME, "Cam updt ... ","ms")
            .addValue(EventID.CM_CHUNK_UPDATE_TIME, "Chk updt ... ","ms")
            .initialise()
            .move(int2(cast(int)gl.windowSize.width-180, Y+16*12));

        this.chunksMonitor = new GLMonitor(gl, "ChunksUsage", "Chunks")
            .colour(WHITE*0.92)
            .formatting("6.0f")
            .addValue(EventID.CHUNKS_TOTAL, "Total ...... ")
            .addValue(EventID.CHUNKS_ON_GPU, "On GPU ..... ")
            .addValue(EventID.CHUNKS_READY, "Ready ...... ")
            .addValue(EventID.CHUNKS_FLYWEIGHT, "Flyweight .. ")
            .initialise()
            .move(int2(cast(int)gl.windowSize.width-180, Y+16*18));
    }
    override void setWorld(World world) {
        super.setWorld(world);

        topBar.setWorld(world);
        minimap.setWorld(world);
        glComputeSceneRenderer.setWorld(world);
        skybox.setVP(world.camera);
    }
    @Implements("RenderView")
    override void destroy() {
        super.destroy();

        console.destroy();
        topBar.destroy();
        bottomBar.destroy();
        minimap.destroy();
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
    @Implements("RenderView")
    override void render(ulong frameNumber, float seconds, float perSecond) {
        if(!isReady()) return;

        renderWatch.reset();
        renderWatch.start();

        glClear(GL_COLOR_BUFFER_BIT);
        console.clear();

        skybox.render();
        glComputeSceneRenderer.render();

        topBar.render();
        bottomBar.render();
        minimap.render();

        renderWatch.stop();

        frameTiming.endFrame(renderWatch.peek().total!"nsecs");
        updateTiming.endFrame(updateWatch.peek().total!"nsecs");

        fpsMonitor.update(0, gl.FPS());
        frametimeMonitor.update(0, frameTiming.average(2));
        updateTimeMonitor.update(0, updateTiming.average(0));

        fpsMonitor.render();
        frametimeMonitor.render();
        updateTimeMonitor.render();
        computeTimeMonitor.render();

        cpuMonitor.render();
        memMonitor.render();

        diskMonitor.render();
        gpuIoMonitor.render();
        chunksMonitor.render();
        console.render();
    }
protected:
    override bool isKeyPressed(uint key) {
        return gl.isKeyPressed(key);
    }
    override bool isMouseButtonPressed(uint button) {
        return gl.isMouseButtonPressed(0);
    }
    override void afterUpdate(bool cameraMoved, float perSecond) {
        skybox.setVP(world.camera);
        glComputeSceneRenderer.afterUpdate(cameraMoved);
    }
    override void renderOptionsChanged() {
        topBar.renderOptionsChanged();
        glComputeSceneRenderer.renderOptionsChanged();
    }
private:
}

