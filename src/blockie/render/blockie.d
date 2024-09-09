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
        this.log("Destroying");
        this.log("#==========================================#");
        this.log("| Event Statistics");
        this.log("#==========================================#");
        foreach(stat; getEvents().getSubscriberStats()) {
            this.log("| %s: 0x%x time: %s count: %s", stat[0], stat[1], stat[2]/1000000.0, stat[3]);
        }

        if(renderView) renderView.destroy();

        auto stats = GC.stats();
        auto profileStats = GC.profileStats();
        this.log("#==========================================#");
        this.log("| GC Statistics");
        this.log("#==========================================#");
        this.log("| Used .............. %s MB (%000,s)", stats.usedSize/(1024*1024), stats.usedSize);
        this.log("| Free .............. %s MB (%000,s)", stats.freeSize/(1024*1024), stats.freeSize);
        this.log("| Collections ....... %s", profileStats.numCollections);
        this.log("| Collection time ... %.2f ms", profileStats.totalCollectionTime.total!"nsecs"/1000000.0);
        this.log("| Pause time ........ %.2f ms", profileStats.totalPauseTime.total!"nsecs"/1000000.0);
        this.log("#==========================================#");
    }
    abstract void run();
protected:
    void initWorld(float2 windowSize) {

        this.log("windowSize = %s", windowSize.to!int);

        string[string] scenes = [
            "1" : "Test Scene 1",
            "2" : "Test Scene 2",
            "3" : "Test Scene 3",
            "4" : "Test Scene 4",
            "4b": "Test Scene 4b",
            "4c": "Test Scene 4c",
            "5" : "Test Scene 5",
            "6" : "Test Scene 6 - Bunny",
            "7" : "Test Scene 7 - HGT",
            "8" : "Test Scene 8",
            "9" : "Test Scene 9"
        ];

        try{
            string w = "9";

            string scene = scenes[w];

            world = World.load(scene);

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
