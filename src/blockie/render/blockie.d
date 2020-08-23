module blockie.render.Blockie;

import blockie.render.all;

abstract class Blockie {
protected:
    string title = "Blockie " ~ version_;
    World world;
    IView view;
    IView nextView;
    RenderView renderView;
public:
    void initialise() {
        log("Starting %s", title);
        writefln("\n%s", title);

        initEvents(1*MB);
    }
    void destroy() {
        log("Events statistics:");
        foreach(stat; getEvents().getSubscriberStats()) {
            log("  %s: 0x%x time: %s count: %s", stat[0], stat[1], stat[2]/1000000.0, stat[3]);
        }
        log("==================");

        if(renderView) renderView.destroy();
    }
    abstract void run();
protected:
    //void doSomething(void delegate(int a) call) {
    //    // doSomething(it => writefln("%s", it));
    //    // doSomething((it) {writefln("%s", it);});
    //    call(10);
    //}
    void initWorld(float2 windowSize) {

        log("windowSize = %s", windowSize.to!int);

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
            version(MODEL1a) pragma(msg, "MODEL1a");
            version(MODEL2) pragma(msg, "MODEL2");
            version(MODEL3) pragma(msg, "MODEL3");
            version(MODEL4) pragma(msg, "MODEL4");
            version(MODEL5) pragma(msg, "MODEL5");
            version(MODEL6) pragma(msg, "MODEL6");

            world.camera.resize(windowSize);

            renderView.setWorld(world);
            nextView = renderView;
        }catch(Throwable e) {
            writefln("Error: %s",e);
            log("Error: %s, e");
        }
    }
}
