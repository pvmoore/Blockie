module blockie.generate.testscene2;

import blockie.generate.all;
/**
 *  Resolution: 1920x1080 (-26*2y)
 *
 *  Chunk   Data            Render  (Max len,br,lv)
 *  Size                    Time
 *  6 r=1    89,722,880     [4.84,3.84,0.11] (24910,340,1024)
 *          117,882,880     [4.01,3.68,0.11] (24985,336,1024)
 *          387,153,920     4.11ms  (25985,320,1024)
 *
 *  7 r=1    86,123,520     [4.55,3.55,0.11] (99662,1364,4096)
 *           89,579,520     [4.33,3.37,0.11] (99737,1360,4096)
 *          117,739,520     [4.00,3.11,0.11]  (100737,1344,4096)
 *          345,067,520     3.73ms- (110337,1280,4096)
 *         2213,826,560     6.11ms  (193537,1024,4096)
 *
 *  8 r=1    85,689,600     [4.46,3.48,0.11] (398670,5460,16384) (341MB)
 *           86,105,600     [4.35,3.37,0.11] (398745,5456,16384) (343MB)
 *           89,561,600     [4.11,3.08,0.11] (399745,5440,16384)
 *          117,721,600     [4.05,3.04,0.11] (409345,5376,16384)
 *          386,992,640     4.84ms  (492545,5120,16384)
 *
 *  9 r=1    85,639,360     3.80ms- (1594702,21844,65536)
 *           85,687,360     3.78ms- (1594777,21840,65536)
 *          128,046,400     3.57ms  (1595777,21824,65536)
 *          131,502,400     3.35ms  (1605377,21760,65536)
 *          159,662,400     4.38ms  (1688577,21504,65536)
 *
 *  10 r=1   85,634,080     4.03ms- (6378830,87380,262144)
 *           85,639,080     3.80ms- (6378905,87376,262144)
 *          127,630,120     3.96ms  (6379905,87360,262144)
 *          128,046,120     3.62ms* (6389505,87296,262144)
 *          131,502,120     3.71ms  (6472705,87040,262144)
 */

final class TestScene2 : SceneGenerator {
    uint width   = 1024*2;    // x
    uint height  = 1024*2;    // y
    uint breadth = 1024*10;   // z

    @Implements("WorldGen")
    World getWorld() {
        World w = new World("Test Scene 2");

        w.sunPos = vec3(1024, 10000, 1024*5);

        w.camera = new Camera3D(
            vec3(width/2,height/2,12700), // position
            vec3(width/2,height/2,0)      // focal point
        );
        w.camera.fovNearFar(60.degrees, 10, 100000);
        return w;
    }
    @Implements("WorldGen")
    void build(WorldEditor edit) {

        edit.startTransaction();

        edit.rectangle(
            ivec3(0,       0, 0),
            ivec3(width-1, 0, breadth-1),
            1,
            V_ROCK1
        );

        edit.commitTransaction();

        log("maxVoxelsLength = %s", maxVoxelsLength);
        log("maxBranches = %s", maxBranches);
        log("maxLeaves   = %s", maxLeaves);
    }
}


