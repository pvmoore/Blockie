module blockie.generate.testscene3;

import blockie.all;
import blockie.generate.all;
/**
 *  Resolution: 1920x1080 (-26*2y)
 *
 *  Chunk   Data            Render  (Max len,br,lv)
 *  Size                    Time
 *  6 r=1   137,402,400     [7.33,6.32,0.11]  (25233,351,1028)
 *          164,355,175     [8.61,7.64,0.11]  (25299,346,1028)
 *          390,445,725    13.53ms (26249,328,1028)
 *
 *  7 r=1   134,846,265     [7.45,6.45,0.11]  (100656,1398,4105)
 *          137,259,040     [7.40,6.40,0.11]  (100706,1393,4105)
 *          164,211,815     [9.6,8.62,0.11]  (101556,1371,4105)
 *          390,302,365    22.85ms  (110931,1298,4105)
 *
 *  8 r=1   134,851,620     [8.10,7.15,0.11]  (403007,5613,16420)
 *          134,828,345     [7.10,6.41,0.11]  (402982,5605,16420)
 *          137,241,120     [7.36,6.39,0.11]  (403407,5566,16420)
 *          164,193,895     [9.12,8.13,0.11]  (412371,5474,16420)
 *          390,284,445    21.18ms  (494796,5187,16420)
 *
 *  9 r=1   134,857,380     8.32ms  (1620578,22760,65722)
 *          134,849,380     7.67ms  (1620553,22752,65722)
 *          134,826,105     7.07ms  (1620353,22688,65722)
 *          137,238,880     7.14ms  (1626528,22487,65722)
 *          164,191,655     9.24ms  (1705428,22059,65722)
 *
 *  10 r=1  134,858,100     8.98ms  (6565751,94021,263450)
 *          134,857,100     8.38ms  (6565726,94013,263450)
 *          134,849,100     7.73ms  (6565526,93949,263450)
 *          134,825,825     7.12ms  (6564651,93466,263450)
 *          137,238,600     7.19ms  (6621551,92158,263450)
 */

final class TestScene3 : WorldGen {
    Mt19937 gen;
    const uint width   = 1024*2;    // x
    const uint height  = 1024*2;    // y
    const uint breadth = 1024*10;    // z
    const uint xx = width/CHUNK_SIZE;
    const uint yy = height/CHUNK_SIZE;
    const uint zz = breadth/CHUNK_SIZE;

    this() {
        this.gen.seed(0);
    }

    @Implements("WorldGen")
    World getWorld() {
        World w = new World("Test Scene 3");
        w.sunPos = vec3(1000, 10000, -700);

        w.camera = new Camera3D(
            vec3(width/2,height/2,12700), // position
            vec3(width/2,height/2,0)      // focal point
        );
        w.camera.fovNearFar(60.degrees, 10, 100000);
        return w;
    }
    @Implements("WorldGen")
    void build(WorldBuilder edit) {

        edit.rectangle(
            ivec3(0,       0, 0),
            ivec3(width-1, 0, breadth-1),
            1,
            V_ROCK1
        );

        for(auto i=0; i<50_000; i++) {
            edit.setVoxel(
                V_ROCK1,
                uniform(0, width, gen),
                uniform(0, height, gen),
                uniform(0, breadth, gen)
            );
        }


        edit.commit();

        log("maxVoxelsLength = %s", maxVoxelsLength);
        log("maxBranches = %s", maxBranches);
        log("maxLeaves   = %s", maxLeaves);
    }
}

