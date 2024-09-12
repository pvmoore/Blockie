module blockie.generate.scenes.testscene1;

import blockie.generate.all;
/**
 *  Resolution: 1920 x 1024
 *
 *  Chunk   Data        Render  (Max len,br,lv)
 *  Size                Time
 *  6 r=1   38,318,002  [2.77,2.26,0.14]  (71008,934,2977) (268MB)
 *    r=2   39,532,202  [2.74,2.21,0.14]  (71008,927,2977)
 *    r=3   50,101,602  2.80ms-  (71483,890,2977)
 *    r=4  148,791,808  5.87ms  (78458,721,2977)
 *
 *  7 r=1   38,183,834  [2.87,2.34,0.14]  (291353,3911,12097) (242MB)
 *    r=2   38,310,834  [2.74,2.26,0.14] (2.99,2.73) (291353,3904,12097)
 *    r=3   39,525,034  [2.91,2.39,0.14]  (291828,3867,12097)
 *    r=4   50,094,434  3.49ms-  (298803,3698,12097)
 *    r=5  148,784,640  8.07ms  (370378,2977,12097)
 *
 *  8 r=1   38,172,338  [3.07,2.56,0.14]  (1180530,16008,48769) (239MB)
 *    r=2   38,182,938  [2.98,2.42,0.14] (1180530,16001,48769)
 *    r=3   38,309,938  [2.99,2.49,0.14]  (1181005,15964,48769)
 *    r=4   39,524,138  [3.51,2.98,0.14]  (1187980,15795,48769)
 *    r=5   60,684,594  6.59ms  (1259555,15074,48769)
 *
 *  9 r=1   38,171,826  3.20ms-  (4752907,64777,195841) (247MB)
 *    r=2   38,172,226  3.05ms-  (4752907,64770,195841)
 *    r=3   48,650,382  4.03ms  (4753382,64733,195841)
 *    r=4   48,782,282  4.37ms  (4760357,64564,195841)
 *    r=5   50,018,982  5.52ms  (4831932,63843,195841)
 *
 *  10 r=1  too big!!
 */
final class TestScene1 : SceneGenerator {
    const uint xsize   = 1024;
    const uint ysize   = 1024;
    const uint zsize   = 1024*2;

    @Implements("WorldGen")
    World getWorld() {
        World w = new World("Test Scene 1");

        w.sunPos = vec3(512, 1024*10, 1024);

        w.camera = new Camera3D(
            vec3(900,1000,3000), // position
            vec3(0,0,0)          // focal point
        );
        w.camera.fovNearFar(60.degrees, 10, 100000);
        return w;
    }
    @Implements("WorldGen")
    void build(WorldEditor edit) {

        edit.startTransaction();

        edit.rectangle(
            ivec3(0,       0, zsize/2-1),
            ivec3(xsize-1, 8, zsize-1),
            4,
            V_ROCK1);

        edit.rectangle(
            ivec3(0,       9, zsize/2-1),
            ivec3(xsize-1, 9, zsize-1),
            1,
            V_GRASS1);

        edit.rectangle(
            ivec3(0, 0,       zsize/2-1),
            ivec3(1, ysize-1, zsize-1),
            1,
            V_ROCK1
        );

        edit.rectangle(
            ivec3(xsize-2, 0,       zsize/2-1),
            ivec3(xsize-1, ysize-1, zsize-1),
            1,
            V_ROCK1
        );

        edit.rectangle(
            ivec3(0,0,0),
            ivec3(xsize-1,ysize-1,zsize/2-1),
            1,
            V_EARTH1);

        //edit.setVoxel(worldcoords(10,10, 2048-2), 1);
        //edit.setVoxel(worldcoords(20,20, 2048-2), 1);
        //edit.setVoxel(worldcoords(30,30, 2048-2), 1);

        edit.commitTransaction();

        log("maxVoxelsLength = %s", maxVoxelsLength);
        log("maxBranches = %s", maxBranches);
        log("maxLeaves   = %s", maxLeaves);
    }
}

