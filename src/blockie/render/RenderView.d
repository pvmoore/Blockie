module blockie.render.RenderView;

import blockie.render.all;

enum RenderOption {
    DISPLAY_VOXEL_SIZES,
    ACCURATE_VOXEL_BOXES
}

abstract class RenderView : IView {
protected:
    World world;
    StopWatch renderWatch;
    StopWatch updateWatch;
    int4 renderRect;
    Timing frameTiming, updateTiming;

    IMonitor cpuMonitor;
    IMonitor memMonitor;
    IMonitor fpsMonitor;
    IMonitor frametimeMonitor;
    IMonitor updateTimeMonitor;
    IMonitor computeTimeMonitor;
    IMonitor diskMonitor;
    IMonitor gpuIoMonitor;
    IMonitor chunksMonitor;
    bool[RenderOption] renderOptions;

    Console console;
    TopBar topBar;
    BottomBar bottomBar;
    MiniMap minimap;
public:
    this() {
        renderOptions[RenderOption.DISPLAY_VOXEL_SIZES] = false;
        renderOptions[RenderOption.ACCURATE_VOXEL_BOXES] = false;
    }
    void destroy() {
        if(memMonitor) memMonitor.destroy();
        if(cpuMonitor) cpuMonitor.destroy();
        if(fpsMonitor) fpsMonitor.destroy();
        if(frametimeMonitor) frametimeMonitor.destroy();
        if(updateTimeMonitor) updateTimeMonitor.destroy();
        if(computeTimeMonitor) computeTimeMonitor.destroy();
        if(diskMonitor) diskMonitor.destroy();
        if(gpuIoMonitor) gpuIoMonitor.destroy();
        if(chunksMonitor) chunksMonitor.destroy();
        if(console) console.destroy();
        if(topBar) topBar.destroy();
        if(bottomBar) bottomBar.destroy();
        if(minimap) minimap.destroy();
    }
    void enteringView() {

    }
    void exitingView() {

    }
    void keyPress(uint keyCode, bool down, uint mods) {
        if(!down) return;

        switch(keyCode) {
            case GLFW_KEY_1:
                setRenderOption(RenderOption.DISPLAY_VOXEL_SIZES,
                    !getRenderOption(RenderOption.DISPLAY_VOXEL_SIZES));
                renderOptionsChanged();
                break;
            case GLFW_KEY_2:
                setRenderOption(RenderOption.ACCURATE_VOXEL_BOXES,
                    !getRenderOption(RenderOption.ACCURATE_VOXEL_BOXES));
                renderOptionsChanged();
                break;
            default:
                break;
        }
    }
    void update(float perSecond) {
        if(!isReady()) return;

        updateWatch.reset();
        updateWatch.start();
        scope(exit) updateWatch.stop();

        bool moved;
        float rotateRatio  = 2 * perSecond;
        float fwdBackRatio = 400 * perSecond;

        if(isMouseButtonPressed(0)) {
            //auto pos = gl.mousePos;
            //writefln("[%s,%s] %s", pos[0], pos[1], world.camera);
        }

        if(isKeyPressed(GLFW_KEY_UP)) {
            world.camera.pitch(rotateRatio);
            moved = true;
        } else if(isKeyPressed(GLFW_KEY_DOWN)) {
            world.camera.pitch(-rotateRatio);
            moved = true;
        } else if(isKeyPressed(GLFW_KEY_LEFT)) {
            world.camera.yaw(-rotateRatio);
            moved = true;
        } else if(isKeyPressed(GLFW_KEY_RIGHT)) {
            world.camera.yaw(rotateRatio);
            moved = true;
        } else if(isKeyPressed(GLFW_KEY_Q)) {
            world.camera.roll(-rotateRatio);
            moved = true;
        } else if(isKeyPressed(GLFW_KEY_W)) {
            world.camera.roll(rotateRatio);
            moved = true;
        } else if(isKeyPressed(GLFW_KEY_A)) {
            world.camera.moveForward(fwdBackRatio);
            moved = true;
        } else if(isKeyPressed(GLFW_KEY_Z)) {
            world.camera.moveForward(-fwdBackRatio);
            moved = true;
        } else if(isKeyPressed(GLFW_KEY_F12)) {
            GC.collect();
            GC.minimize();
            writefln("Collecting garbage");
        }
        if(moved) {
            log("camera = %s", world.camera);
        }
        afterUpdate(moved, perSecond);
    }
    final void render(ulong frameNumber, float seconds, float perSecond) {
        if(!isReady()) return;

        renderWatch.reset();
        renderWatch.start();

        doRender(frameNumber, seconds, perSecond);

        // render UI elements
        console.clear();
        topBar.render();
        bottomBar.render();
        minimap.render();

        renderWatch.stop();

        frameTiming.endFrame(renderWatch.peek().total!"nsecs");
        updateTiming.endFrame(updateWatch.peek().total!"nsecs");

        fpsMonitor.update(0, getFps());
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
    void setWorld(World world) {
        this.world = world;
        world.camera.resize(renderRect.dimension);

        topBar.setWorld(world);
        minimap.setWorld(world);
    }
    bool getRenderOption(RenderOption opt) {
        return renderOptions[opt];
    }
    void setRenderOption(RenderOption opt, bool value) {
        renderOptions[opt] = value;
    }
protected:
    abstract bool isKeyPressed(uint key);
    abstract bool isMouseButtonPressed(uint key);
    abstract void afterUpdate(bool cameraMoved, float perSecond);
    abstract void renderOptionsChanged();
    abstract float2 getWindowSize();
    abstract void doRender(ulong frameNumber, float seconds, float perSecond);
    abstract float getFps();

    bool isReady() {
        return world !is null;
    }
    void calculateRenderRect(float2 windowSize) {
        this.renderRect = IntRect(0, 20, cast(int)windowSize.width, (cast(int)windowSize.height-20)-20);

        uint rem = renderRect.height&7;
        if(rem!=0) {
            /// ensure height is a multiple of 8
            renderRect.y      += rem;
            renderRect.height -= rem;
        }
    }
    void initialiseMonitors() {
        int width = getWindowSize().x.as!int;
        enum Y = 22;

        memMonitor
            .initialise()
            .move(int2(width-180, Y+16*6));

        cpuMonitor
            .initialise()
            .move(int2(width-180, Y+16*23));

        fpsMonitor
            .colour(WHITE*1.1)
            .formatting("4.2f")
            .as!EventStatsMonitor
            .addValue(EventID.NONE, "FPS ....... ")
            .initialise()
            .move(int2(width-180, Y));

        frametimeMonitor
            .colour(WHITE*0.92)
            .formatting("4.2f")
            .as!EventStatsMonitor
            .addValue(EventID.NONE, "Frame ..... ", "ms")
            .initialise()
            .move(int2(width-180, Y+16*1));

        updateTimeMonitor
            .colour(WHITE*0.92)
            .formatting("4.2f")
            .as!EventStatsMonitor
            .addValue(EventID.NONE, "Update .... ", "ms")
            .initialise()
            .move(int2(width-180, Y+16*2));

        computeTimeMonitor
            .colour(WHITE*0.92)
            .formatting("5.2f")
            .as!EventStatsMonitor
            .addValue(EventID.COMPUTE_RENDER_TIME, "Render ....", "ms")
            .addValue(EventID.COMPUTE_TIME, "Compute ...", "ms")
            .initialise()
            .move(int2(width-180, Y+16*3));

        diskMonitor
            .colour(WHITE*0.92)
            .formatting("3.1f")
            .as!EventStatsMonitor
            .addValue(EventID.STORAGE_READ,  "Read ... ", "")
            .addValue(EventID.STORAGE_WRITE, "Write .. ", "")
            .initialise()
            .move(int2(width-180, Y+16*9));

        gpuIoMonitor
            .colour(WHITE*0.92)
            .formatting("4.2f")
            .as!EventStatsMonitor
            .addValue(EventID.GPU_WRITES, "Writes ..... ")
            .addValue(EventID.GPU_VOXELS_USAGE, "Used (vx) .. ")
            .addValue(EventID.GPU_CHUNKS_USAGE, "Used (ch) .. ", "K")
            .addValue(EventID.CM_CAMERA_MOVE_UPDATE_TIME, "Cam updt ... ","ms")
            .addValue(EventID.CM_CHUNK_UPDATE_TIME, "Chk updt ... ","ms")
            .initialise()
            .move(int2(width-180, Y+16*12));

        chunksMonitor
            .colour(WHITE*0.92)
            .formatting("6.0f")
            .as!EventStatsMonitor
            .addValue(EventID.CHUNKS_TOTAL, "Total ...... ")
            .addValue(EventID.CHUNKS_ON_GPU, "On GPU ..... ")
            .addValue(EventID.CHUNKS_READY, "Ready ...... ")
            .addValue(EventID.CHUNKS_FLYWEIGHT, "Flyweight .. ")
            .initialise()
            .move(int2(width-180, Y+16*18));
    }
}