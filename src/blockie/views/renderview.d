module blockie.views.renderview;

import blockie.all;

public:

enum RenderOption {
    DISPLAY_VOXEL_SIZES,
    ACCURATE_VOXEL_BOXES
}

final class RenderView : IView {
private:
    World world;
    bool needToInitWorld;
    StopWatch renderWatch;
    StopWatch updateWatch;
    int4 renderRect;
    Timing fpsTiming, frameTiming, updateTiming;
    bool[RenderOption] renderOptions;

    OpenGL gl;
    GLComputeRenderer glComputeSceneRenderer;
    SkyBox skybox;
    Console console;
    TopBar topBar;
    BottomBar bottomBar;
    MiniMap minimap;
public:
    this(OpenGL gl) {
        this.gl = gl;

        calculateRenderRect();

        setRenderOption(RenderOption.DISPLAY_VOXEL_SIZES, false);
        setRenderOption(RenderOption.ACCURATE_VOXEL_BOXES, false);

        this.console      = new Console(gl, renderRect.y);
        this.topBar       = new TopBar(gl, this, renderRect.y+1);
        this.bottomBar    = new BottomBar(gl, this, );
        this.minimap      = new MiniMap(gl);
        this.fpsTiming    = new Timing(10,3);
        this.frameTiming  = new Timing(10,3);
        this.updateTiming = new Timing(10,1);

        this.glComputeSceneRenderer = new GLComputeRenderer(gl, this, renderRect);

        this.skybox = new SkyBox(gl, "/pvmoore/_assets/images/skyboxes/skybox1");

        const Y = 22;

        getFPSMonitor().move(
            ivec2(cast(int)gl.windowSize.width-180, Y)
        );
        getFrameTimeMonitor().move(
            ivec2(cast(int)gl.windowSize.width-180, Y+16*1)
        );
        getUpdateTimeMonitor().move(
            ivec2(cast(int)gl.windowSize.width-180, Y+16*2)
        );
        getComputeMonitor().move(
            ivec2(cast(int)gl.windowSize.width-180, Y+16*3)
        );
        getMEMMonitor().move(
            ivec2(cast(int)gl.windowSize.width-180, Y+16*6)
        );
        getDiskMonitor().move(
            ivec2(cast(int)gl.windowSize.width-180, Y+16*9)
        );
        getGPUIOMonitor().move(
            ivec2(cast(int)gl.windowSize.width-180, Y+16*12)
        );
        getChunksMonitor().move(
            ivec2(cast(int)gl.windowSize.width-180, Y+16*18)
        );
        getCPUMonitor().move(
            ivec2(cast(int)gl.windowSize.width-180, Y+16*23)
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
    bool getRenderOption(RenderOption opt) {
        return renderOptions[opt];
    }
    void setRenderOption(RenderOption opt, bool value) {
        renderOptions[opt] = value;
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

        world.camera.resize(renderRect.dimension);
    }
    void keyPress(uint keyCode, bool down, uint mods) {
        if(!down) return;

        switch(keyCode) {
            case GLFW_KEY_1:
                setRenderOption(RenderOption.DISPLAY_VOXEL_SIZES,
                    !getRenderOption(RenderOption.DISPLAY_VOXEL_SIZES));
                topBar.renderOptionsChanged();
                glComputeSceneRenderer.renderOptionsChanged();
                break;
            case GLFW_KEY_2:
                setRenderOption(RenderOption.ACCURATE_VOXEL_BOXES,
                    !getRenderOption(RenderOption.ACCURATE_VOXEL_BOXES));
                topBar.renderOptionsChanged();
                glComputeSceneRenderer.renderOptionsChanged();
                break;
            default:
                break;
        }
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
        float rotateRatio  = 0.02 * timeDelta;
        float fwdBackRatio = 0.4*20 * timeDelta;

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
            log("camera = %s", world.camera);
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
private:
    void calculateRenderRect() {
        auto dim = gl.windowSize;
        renderRect = IntRect(0, 20, cast(int)dim.width, (cast(int)dim.height-20)-20);
        uint rem = renderRect.height&7;
        if(rem!=0) {
            /// ensure height is a multiple of 8
            renderRect.y      += rem;
            renderRect.height -= rem;
        }
    }
}

