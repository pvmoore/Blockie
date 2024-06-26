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
    enum {
        // 1080p resolution
        WIDTH  = 1920,
        HEIGHT = 1080,

        VOXEL_BUFFER_SIZE = 1300.MB,
        CHUNK_BUFFER_SIZE = 4.MB
    }

    void initialise() {
        setEagerFlushing(true);
        this.log("Starting %s", title);
        this.log("\n%s", title);

        initEvents(1.MB.as!int);
    }
    void destroy() {
        this.log("Destroy called");
        this.log("Events statistics:");
        foreach(stat; getEvents().getSubscriberStats()) {
            this.log("  %s: 0x%x time: %s count: %s", stat[0], stat[1], stat[2]/1000000.0, stat[3]);
        }
        this.log("==================");

        if(renderView) renderView.destroy();
    }
    abstract void run();
protected:
    void initWorld(float2 windowSize) {

        this.log("windowSize = %s", windowSize.to!int);

        try{
            string w = "1";

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

            this.log("w = %s", w);

            version(MODEL1) pragma(msg, "MODEL1");
            version(MODEL1a) pragma(msg, "MODEL1a");
            version(MODEL2) pragma(msg, "MODEL2");
            version(MODEL3) pragma(msg, "MODEL3");
            version(MODEL4) pragma(msg, "MODEL4");
            version(MODEL5) pragma(msg, "MODEL5");
            version(MODEL6) pragma(msg, "MODEL6");

            version(MODEL_B) pragma(msg, "[Submodel B]");

            world.camera.resize(windowSize);

            renderView.setWorld(world);
            nextView = renderView;

        }catch(Throwable e) {
            this.log("Error: %s, e");
        }
    }
}
