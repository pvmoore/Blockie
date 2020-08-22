module blockie.render.blockie;

import blockie.render.all;

interface Blockie {
    void initialise();
    void destroy();
    void run();
}

final class CommonBlockie {
    World world;
    IView view;
    IView nextView;

    // todo
}

final class VKBlockie {
private:

public:
    void initialise() {

    }
    void destroy() {

    }
    void run() {

    }
}

final class GLBlockie : ApplicationListenerAdapter, Blockie {
protected:
    string title = "Blockie " ~ version_;
    OpenGL gl;
    World world;
    IView view;
    IView nextView;
    GLRenderView renderView;
public:
    void initialise() {
        log("Starting %s", title);
        writefln("\n%s", title);

        initEvents(1*MB);

        version(VULKAN) {
            log("Using Vulkan");
        }

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

        renderView = new GLRenderView(gl);

        import std : fromStringz;
        import core.cpuid: processor;
        string deviceName = cast(string)fromStringz(glGetString(GL_RENDERER));
        title ~= " :: %s, %s".format(processor(), deviceName);
        gl.setWindowTitle(title);

        //auto t = task(&initWorld);
        //t.executeInNewThread();
        initWorld();

        gl.showWindow(true);
    }
    void destroy() {
        log("==================");
        log("Events statistics:");
        foreach(stat; getEvents().getSubscriberStats()) {
            log("  %s: 0x%x time: %s count: %s", stat[0], stat[1], stat[2]/1000000.0, stat[3]);
        }
        log("==================");

        if(renderView) renderView.destroy();
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
            string w = "8";

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
            version(MODEL5) pragma(msg, "MODEL5");
            version(MODEL6) pragma(msg, "MODEL6");


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
    override void render(ulong frameNumber, float seconds, float perSecond) {
        if(!gl) return;
        if(nextView) {
            if(view) view.exitingView();
            view = nextView;
            view.enteringView();
            nextView = null;
        }
        if(!view) return;
        view.render(frameNumber, seconds, perSecond);
        view.update(perSecond);

//        if((frameNumber&255)==0) {
//            writefln("Event subscribers {");
//            foreach(t; getEvents().getSubscriberStats) {
//                writefln("\t%s :  mask=%x time=%s millis msgs=%s", t[0], t[1], t[2]/1000000.0, t[3]);
//            }
//            writefln("}");
//        }
    }
}


