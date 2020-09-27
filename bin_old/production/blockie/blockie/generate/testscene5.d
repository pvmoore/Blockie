module blockie.generate.testscene5;

import blockie.all;
import blockie.generate.all;
/**
 *  Resolution: 1920x1080 (-26*2y)
 *
 *  Chunk   Data            Render    (Max len,br,lv)
 *  Size                    Time
 *  6 r=1   20,517,921      [1.75,1.32,0.12]    (64180,1121,2294)
 *    r=2   21,154,271      [1.80,1.26,0.12]    (64155,1113,2294)
 *    r=3   26,517,746      1.45ms    (64330,1060,2294)
 *
 *  7 r=1   20,444,737      [1.74,1.36,0.12]    (248782,4404,8699)
 *          20,514,337      [1.67,1.30,0.12]    (248782,4397,8699)
 *          21,150,687      [2.30,1.38,0.12]    (249282,4361,8699)
 *          26,514,162      1.90ms    (255507,4162,8699)
 *          70,689,987      2.98ms    (322310,3229,8699)
 *
 *  8 r=1   20,437,889      [1.94,1.50,0.12]    (1009932,17810,35291)
 *          20,444,289      [1.81,1.43,0.12]    (1009932,17803,35291)
 *          20,513,889      [1.96,1.50,0.12]    (1010407,17766,35291)
 *          21,150,239      [2.77,1.87,0.12]    (1017607,17606,35291)
 *          26,513,714      3.11ms    (1088632,16863,35291)
 *
 *  9 r=1   20,437,533      1.88ms    (3410048,54022,128807)
 *          20,437,833      1.73ms    (3410048,54015,128807)
 *          20,444,233      1.63ms    (3410648,53983,128807)
 *          20,513,833      1.89ms    (3418498,53849,128807)
 *          21,150,183      2.64ms    (3494598,53309,128807)
 *  10      too big!!
 */
final class TestScene5 : SceneGenerator {
    const uint width   = 1024;    // x
    const uint height  = 1024;    // y
    const uint breadth = 1024;   // z
    const uint xx = width/CHUNK_SIZE;
    const uint yy = height/CHUNK_SIZE;
    const uint zz = breadth/CHUNK_SIZE;

    @Implements("WorldGen")
    World getWorld() {
        World w = new World("Test Scene 5");

        w.sunPos = vec3(512, 10000, 512);

        w.camera = new Camera3D(
            vec3(width*2-300,height/2,breadth*2-300), // position
            vec3(0,height/2,0)      // focal point
        );
        w.camera.fovNearFar(60.degrees, 10, 100000);
        return w;
    }
    @Implements("WorldGen")
    void build(WorldEditor edit) {

        edit.startTransaction();

        for(auto y=0; y<1; y++)
        for(auto z=0; z<breadth; z++)
        for(auto x=0; x<width; x++) {
            edit.setVoxel(worldcoords(x,y,z), V_GRASS1);
        }

        // main sphere
        edit.sphere(
            ivec3(512,512,512), 290,300, V_EARTH1);

        // left
        edit.sphere(
            ivec3(512+300,512,512), 50,75, V_ROCK1);
        // right
        edit.sphere(
            ivec3(512-300,512,512), 50,75, V_ROCK1);
        // front
        edit.sphere(
            ivec3(512,512,512+300), 50,75, V_ROCK1);
        // top
        edit.sphere(
            ivec3(512,512+300,512), 50,75, V_ROCK1);
        // bottom
        edit.sphere(
            ivec3(512,512-300,512), 50,75, V_ROCK1);

        edit.commitTransaction();

        log("maxVoxelsLength = %s", maxVoxelsLength);
        log("maxBranches = %s", maxBranches);
        log("maxLeaves   = %s", maxLeaves);
    }
}

