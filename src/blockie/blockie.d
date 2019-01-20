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
            // (A) - Aggressive skipLOD producing artifacts in some scenes
            // (B) - Better looking skipLOD

            //      FPS(A)  (B)   GPU(MB)     Model2
            // 1:   605     742      2      - 830   (0MB)
            // 2:   1340   1140      5      - 1300  (0MB)
            // 3:   455     352      8      - 460   (1MB)
            // 4:   425     308    242      - 425   (247MB)

            // 4b:  360     290     54      - 383   (46MB)
            // 4c:  345     290     79      - 376   (59MB)
            // 5:   1025    956      2      - 1070  (1MB)
            // 6:   780     564     53      - 711   (41MB)
            // 7:   415     375     32      - 460   (28MB)

            string w = "4";

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
                default: break;
            }

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


