module blockie.views.renderview;

import blockie.all;

public enum SceneRenderer {
    SOFTWARE, OPENCL, GL_COMPUTE
};

final class RenderView : IView {
private:
    OpenGL gl;
    World world;
    bool needToInitWorld;
    GLComputeRenderer glComputeSceneRenderer;
    SkyBox skybox;
    Console console;
    TopBar topBar;
    BottomBar bottomBar;
    MiniMap minimap;
    StopWatch renderWatch;
    StopWatch updateWatch;
    IntRect renderRect;
    Timing fpsTiming, frameTiming, updateTiming;
    SceneRenderer renderer = SceneRenderer.GL_COMPUTE;
public:
    this(OpenGL gl) {
        this.gl  = gl;

        calculateRenderRect();

        this.console   = new Console(gl, renderRect.y);
        this.topBar    = new TopBar(gl, renderRect.y);
        this.bottomBar = new BottomBar(gl);
        this.minimap   = new MiniMap(gl);
        this.fpsTiming = new Timing(10,3);
        this.frameTiming = new Timing(10,3);
        this.updateTiming = new Timing(10,1);

        this.glComputeSceneRenderer = new GLComputeRenderer(gl, renderRect);

        this.skybox = new SkyBox(gl, "/pvmoore/_assets/images/skyboxes/skybox1");

        getFPSMonitor().move(
            ivec2(cast(int)gl.windowSize.width-280,30)
        );
        getFrameTimeMonitor().move(
            ivec2(cast(int)gl.windowSize.width-280,60)
        );
        getUpdateTimeMonitor().move(
            ivec2(cast(int)gl.windowSize.width-280,90)
        );
        getComputeMonitor().move(
            ivec2(cast(int)gl.windowSize.width-280,130)
        );
        getCPUMonitor().move(
            ivec2(cast(int)gl.windowSize.width-280,230)
        );
        getMEMMonitor().move(
            ivec2(cast(int)gl.windowSize.width-280,500)
        );
        getDiskMonitor().move(
            ivec2(cast(int)gl.windowSize.width-280,600)
        );
        getGPUIOMonitor().move(
            ivec2(cast(int)gl.windowSize.width-280,700)
        );
        getChunksMonitor().move(
            ivec2(cast(int)gl.windowSize.width-280,870)
        );

    }
    void destroy() {
        console.destroy();
        topBar.destroy();
        bottomBar.destroy();
        minimap.destroy();
        skybox.destroy();
        glComputeSceneRenderer.destroy();
    }
    void calculateRenderRect() {
        auto dim = gl.windowSize;
        renderRect = IntRect(0, 26, cast(int)dim.width, (cast(int)dim.height-26)-26);
        uint rem = renderRect.height&7;
        if(rem!=0) {
            // ensure height is a multiple of 8
            renderRect.y      += rem;
            renderRect.height -= rem;
        }
        log("renderRect = %s", renderRect);
    }
    void enteringView() {
        glClearColor(0.1, 0, 0, 0);

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);

        // for the skybox
        glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);

        CheckGLErrors();
    }
    void exitingView() {

    }
    void setWorld(World world) {
        this.world           = world;
        this.needToInitWorld = true;
    }
    void update(float timeDelta) {
        updateWatch.reset();
        updateWatch.start();
        scope(exit) updateWatch.stop();

        if(!world) return;

        if(needToInitWorld) {
            topBar.setWorld(world);
            minimap.setWorld(world);
            glComputeSceneRenderer.setWorld(world);
            skybox.setVP(world.camera);
            needToInitWorld = false;
        }

        bool moved;
        float rotateRatio  = 0.01 * timeDelta;
        float fwdBackRatio = 0.25*20 * timeDelta;

        if(gl.isMouseButtonPressed(0)) {
            auto pos = gl.mousePos;
            //writefln("[%s,%s] %s", pos[0], pos[1], world.camera);
        }

        if(gl.isKeyPressed(GLFW_KEY_UP)) {
            world.camera.pitch(rotateRatio);
            moved = true;
        } else if(gl.isKeyPressed(GLFW_KEY_DOWN)) {
            world.camera.pitch(-rotateRatio);
            moved = true;
        } else if(gl.isKeyPressed(GLFW_KEY_LEFT)) {
            world.camera.yaw(-rotateRatio);
            moved = true;
        } else if(gl.isKeyPressed(GLFW_KEY_RIGHT)) {
            world.camera.yaw(rotateRatio);
            moved = true;
        } else if(gl.isKeyPressed(GLFW_KEY_Q)) {
            world.camera.roll(-rotateRatio);
            moved = true;
        } else if(gl.isKeyPressed(GLFW_KEY_W)) {
            world.camera.roll(rotateRatio);
            moved = true;
        } else if(gl.isKeyPressed(GLFW_KEY_A)) {
            world.camera.moveForward(fwdBackRatio);
            moved = true;
        } else if(gl.isKeyPressed(GLFW_KEY_Z)) {
            world.camera.moveForward(-fwdBackRatio);
            moved = true;
        } else if(gl.isKeyPressed(GLFW_KEY_F12)) {
            GC.collect();
            GC.minimize();
            writefln("Collecting garbage");
        }
        if(moved) {
            writefln("camera = %s", world.camera);
            skybox.setVP(world.camera);
        }
        glComputeSceneRenderer.afterUpdate(moved);
    }
    void render(long frameNumber, long normalisedFrameNumber, float timeDelta) {
        if(!world || needToInitWorld) return;

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
        fpsTiming.endFrame(cast(ulong)(1000000*60.0/timeDelta));

        console.render();

        getFPSMonitor().setValues(fpsTiming.average(2));
        getUpdateTimeMonitor().setValues(updateTiming.average(0));
        getFrameTimeMonitor().setValues(frameTiming.average(2));

        getFPSMonitor().render();
        getUpdateTimeMonitor().render();
        getFrameTimeMonitor().render();
        getComputeMonitor().render();
        getCPUMonitor().render();
        getMEMMonitor().render();
        getDiskMonitor().render();
        getGPUIOMonitor().render();
        getChunksMonitor().render();
    }
}

