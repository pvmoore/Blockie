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
    float2 windowSize;
    int4 renderRect;
    Timing frameTiming, updateTiming;

    bool[RenderOption] renderOptions;

    TopBar topBar;
    BottomBar bottomBar;
    IRenderer computeRenderer;

    StatsUI statsUI;
public:
    this(float2 windowSize) {
        this.windowSize   = windowSize;
        this.frameTiming  = new Timing(10,3);
        this.updateTiming = new Timing(10,1);

        renderOptions[RenderOption.DISPLAY_VOXEL_SIZES] = false;
        renderOptions[RenderOption.ACCURATE_VOXEL_BOXES] = false;

        calculateRenderRect(windowSize);
    }
    void destroy() {
        if(topBar) topBar.destroy();
        if(bottomBar) bottomBar.destroy();
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
    void update(AbsRenderData renderData) {
        if(!isReady()) return;

        updateWatch.reset();
        updateWatch.start();

        bool moved;
        float rotateRatio  = 2 * renderData.perSecond;
        float fwdBackRatio = 400 * renderData.perSecond;

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

        topBar.update(renderData);
        bottomBar.update(renderData);

        if(moved) {
            this.log("camera = %s", world.camera);
        }
        updateScene(renderData, moved);

        updateWatch.stop();
        updateTiming.endFrame(updateWatch.peek().total!"nsecs");
    }
    final void render(AbsRenderData renderData) {
        if(!isReady()) return;

        renderWatch.reset();
        renderWatch.start();

        renderScene(renderData);

        // render UI elements
        topBar.render(renderData);
        bottomBar.render(renderData);

        statsUI.renderFrame(renderData);


        renderWatch.stop();
        frameTiming.endFrame(renderWatch.peek().total!"nsecs");
    }
    void setWorld(World world) {
        this.world = world;
        world.camera.resize(renderRect.dimension);

        topBar.setWorld(world);
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
    abstract void updateScene(AbsRenderData renderData, bool cameraMoved);
    abstract void renderScene(AbsRenderData renderData);
    abstract float getFps();

    bool isReady() {
        return world !is null;
    }
private:
    void renderOptionsChanged() {
        topBar.renderOptionsChanged();
        computeRenderer.renderOptionsChanged();
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
}