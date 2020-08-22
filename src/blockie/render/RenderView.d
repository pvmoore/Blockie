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

    abstract bool isKeyPressed(uint key);
    abstract bool isMouseButtonPressed(uint key);
    abstract void afterUpdate(bool cameraMoved, float perSecond);
    abstract void renderOptionsChanged();

    bool isReady() {
        return world !is null;
    }
    void calculateRenderRect(float2 windowSize) {
        renderRect = IntRect(0, 20, cast(int)windowSize.width, (cast(int)windowSize.height-20)-20);
        uint rem = renderRect.height&7;
        if(rem!=0) {
            /// ensure height is a multiple of 8
            renderRect.y      += rem;
            renderRect.height -= rem;
        }
    }
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
    abstract void render(ulong frameNumber, float seconds, float perSecond);

    void setWorld(World world) {
        this.world = world;
        world.camera.resize(renderRect.dimension);
    }
    bool getRenderOption(RenderOption opt) {
        return renderOptions[opt];
    }
    void setRenderOption(RenderOption opt, bool value) {
        renderOptions[opt] = value;
    }
private:
}