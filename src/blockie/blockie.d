module blockie.blockie;

import blockie.all;

final class Blockie : ApplicationListenerAdapter {
private:
    const string title = "Blockie " ~ version_;
    OpenGL gl;
    World world;
    IView view;
    IView nextView;
    RenderView renderView;
public:
    void initialise() {
        log("Starting %s", title);
        writefln("\n%s", title);

        initEvents(1*MB);

        this.gl = new OpenGL(this, (h) {
            h.width        = 1200;
            h.height       = 800;
            h.title        = title;
            h.windowed     = true;
            h.showWindow   = false;
            h.samples      = 0;
            h.glVersionMaj = 4;
            h.glVersionMin = 3;
            h.fontDirectory = "/pvmoore/_assets/fonts/hiero/";
        });

        log("screen = %s", gl.windowSize.to!int);

        getCPUMonitor().initialise(gl);
        getMEMMonitor().initialise(gl);
        getDiskMonitor().initialise(gl);
        getGPUIOMonitor().initialise(gl);
        getChunksMonitor().initialise(gl);
        getFPSMonitor().initialise(gl);
        getUpdateTimeMonitor().initialise(gl);
        getFrameTimeMonitor().initialise(gl);
        getComputeMonitor().initialise(gl);

        renderView = new RenderView(gl);

        //auto t = task(&initWorld);
        //t.executeInNewThread();
        initWorld();

        gl.showWindow(true);
    }
    void destroy() {
        writefln("");
        if(renderView) renderView.destroy();
        destroyMonitors();
        if(gl) gl.destroy();
        gl = null;
    }
    void run() {
        if(gl) gl.enterMainLoop();
    }
    //void doSomething(void delegate(int a) call) {
    //    // doSomething(it => writefln("%s", it));
    //    // doSomething((it) {writefln("%s", it);});
    //    call(10);
    //}
    void initWorld() {

        //float3 dir = float3(1,1,0.5).normalised;
        //writefln("dir=%s invDir=%s", dir, float3(1)/dir);
        //dir = -dir;
        //writefln("dir=%s invDir=%s", dir, float3(1)/dir);

        try{
            //     |  1            | 2             | 3              | 4
            //     |               |               |                |
            // 1:  |  768 (2 MB)   |  862 (0 MB)   |  940 (0 MB)    | 894 (1 MB)
            // 2:  | 1190 (5 MB)   | 1380 (0 MB)   | 1440 (2 MB)    | 1410 (12 MB)
            // 3:  |  356 (8MB)    |  458 (1 MB)   |  544 (5 MB)    | 402 (25 MB)
            // 4:  |  317 (242 MB) |  397 (247 MB) |  430 (286 MB)  | 380 (402 MB)
            // 4b: |  297 (54 MB)  |  382 (46 MB)  |  413 (56 MB)   | 375 (75 MB)
            // 4c: |  284 (79 MB)  |  366 (59 MB)  |  395 (68 MB)   | 368 (82 MB)
            // 5:  |  980 (2 MB)   | 1124 (1 MB)   | 1185 (1 MB)    | 1075 (1 MB)
            // 6:  |  575 (53 MB)  |  725 (41 MB)  |  780 (42 MB)   | 715 (35 MB)
            // 7:  |  390 (32 MB)  |  455 (28 MB)  |  498 (31 MB)   | 474 (242 MB)
            // 8:  |  523 (1 MB)   |  662 (0 MB)   |  702 (1 MB)    | 667 (1 MB)

            // Notes:
            //    Model 3 has superior speed compared to Model 2 with only
            //    a small cost in extra memory usage so should be preferred.

            string w = "8";

            World world;
            switch(w) {
                case "1" : world = World.load("Test Scene 1"); break;
                case "2" : world = World.load("Test Scene 2"); break;
                case "3" : world = World.load("Test Scene 3"); break;
                case "4" : world = World.load("Test Scene 4"); break;
                case "4b": world = World.load("Test Scene 4b"); break;
                case "4c": world = World.load("Test Scene 4c"); break;
                case "5" : world = World.load("Test Scene 5"); break;
                case "6" : world = World.load("Test Scene 6 - Bunny"); break;
                case "7" : world = World.load("Test Scene 7 - HGT"); break;
                case "8" : world = World.load("Test Scene 8"); break;
                default: break;
            }

            version(MODEL1) pragma(msg, "MODEL1");
            version(MODEL2) pragma(msg, "MODEL2");
            version(MODEL3) pragma(msg, "MODEL3");
            version(MODEL4) pragma(msg, "MODEL4");


            world.camera.resize(gl.windowSize);

            renderView.setWorld(world);
            nextView = renderView;
        }catch(Throwable e) {
            writefln("Error: %s",e);
        }
    }
    @Implements("ApplicationListener")
    override void keyPress(uint keyCode, uint scanCode, bool down, uint mods) nothrow {
        try{
            renderView.keyPress(keyCode, down, mods);
        }catch(Exception e) {}
    }
    /// always called on the main thread
    @Implements("ApplicationListener")
    override void render(long frameNumber,
                         long normalisedFrameNumber,
                         float timeDelta)
    {
        if(!gl) return;
        if(nextView) {
            if(view) view.exitingView();
            view = nextView;
            view.enteringView();
            nextView = null;
        }
        if(!view) return;
        view.render(frameNumber, normalisedFrameNumber, timeDelta);
        view.update(timeDelta);

//        if((frameNumber&255)==0) {
//            writefln("Event subscribers {");
//            foreach(t; getEvents().getSubscriberStats) {
//                writefln("\t%s :  mask=%x time=%s millis msgs=%s", t[0], t[1], t[2]/1000000.0, t[3]);
//            }
//            writefln("}");
//        }
    }
}


