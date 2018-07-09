module blockie.blockie;

import blockie.all;

version(GC_STATS) {
extern(C) __gshared string[] rt_options = [
    "gcopt=profile:1"
];
}

final class Blockie : ApplicationListenerAdapter {
private:
    const string title = "Blockie " ~ version_;
    OpenGL gl;
    World world;
    IView view;
    IView nextView;
    InitView initView;
    RenderView renderView;
public:
    void initialise() {
        log("Starting %s", title);

        initEvents(1024*1024);

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

        log("screen = %s", gl.windowSize);

        getCPUMonitor().init(gl);
        getMEMMonitor().init(gl);
        getDiskMonitor().init(gl);
        getGPUIOMonitor().init(gl);
        getChunksMonitor().init(gl);
        getFPSMonitor().init(gl);
        getUpdateTimeMonitor().init(gl);
        getFrameTimeMonitor().init(gl);
        getComputeMonitor().init(gl);

        initView   = new InitView(gl);
        renderView = new RenderView(gl);

        view = initView;
        view.enteringView();

        //auto t = task(&initWorld);
        //t.executeInNewThread();
        initWorld();

        gl.showWindow(true);
    }
    void destroy() {
        if(initView) initView.destroy();
        if(renderView) renderView.destroy();
        destroyMonitors();
        if(gl) gl.destroy();
        gl = null;
    }
    void run() {
        if(gl) gl.enterMainLoop();
    }
    void doSomething(void delegate(int a) call) {
        // doSomething(it => writefln("%s", it));
        // doSomething((it) {writefln("%s", it);});
        call(10);
    }
    void initWorld() {
        try{
            //Thread.getThis().isDaemon = true;

            vec3 hex  = vec3(0x28,0x4a, 0x57);
            vec3 rgb  = hex/255.0f;
            writefln("hex=%s", hex);
            writefln("rgb=(%s)", rgb);

            // When VIEW_WINDOW==(25,8,25) 1024^^3 chunks
            // air dradius=6
            // 1:   2.10
            // 2:   1.02
            // 3:   5.75
            // 4:   5.00
            // 5:   1.90
            // 6:   2.30
            // 7:   4.30

            string w = "4";

            World world;
            switch(w) {
                case "1" : world = loadWorld("Test Scene 1"); break;
                case "2" : world = loadWorld("Test Scene 2"); break;
                case "3" : world = loadWorld("Test Scene 3"); break;
                case "4" : world = loadWorld("Test Scene 4"); break;
                case "4b": world = loadWorld("Test Scene 4b"); break;
                case "4c": world = loadWorld("Test Scene 4c"); break;
                case "5" : world = loadWorld("Test Scene 5"); break;
                case "6" : world = loadWorld("Test Scene 6 - Bunny"); break;
                case "7" : world = loadWorld("Test Scene 7 - HGT"); break;
                default: break;
            }

            world.camera.resize(gl.windowSize);

            renderView.setWorld(world);
            nextView = renderView;
        }catch(Throwable e) {
            writefln("Error: %s",e);
        }
    }
    /// always called on the main thread
    override void render(long frameNumber,
                         long normalisedFrameNumber,
                         float timeDelta)
    {
        if(!gl) return;
        if(nextView) {
            view.exitingView();
            view = nextView;
            view.enteringView();
            nextView = null;
        }
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


