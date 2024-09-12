module blockie.generate.scenes.testscene6_bunny;

import blockie.generate.all;
/**
 *
 */
final class TestScene6_bunny : SceneGenerator {
    const uint xsize   = 1024*3;
    const uint ysize   = 1024*2;
    const uint zsize   = 1024*3;

    @Implements("WorldGen")
    World getWorld() {
        World w = new World("Test Scene 6 - Bunny");

        w.sunPos = vec3(512, 1024*10, 1024);

        w.camera = new Camera3D(
            vec3(xsize/2,ysize/2,5000), // position
            vec3(xsize/2,500,xsize/2)     // focal point
        );
        w.camera.fovNearFar(60.degrees, 10, 100000);
        return w;
    }
    @Implements("WorldGen")
    void build(WorldEditor edit) {

        edit.startTransaction();

        // floor
        edit.rectangle(ivec3(0,       0, 0),
                       ivec3(xsize-1, 1, zsize-1),
                       1,
                       V_ROCK1);

        loadBunny(edit);

        edit.commitTransaction();

        log("maxVoxelsLength = %s", maxVoxelsLength);
        log("maxBranches = %s", maxBranches);
        log("maxLeaves   = %s", maxLeaves);
    }
private:
    /**
     *  Bunny slices are in files "1" to "361".
     *  They are each 512 x 512 x ushort (little-endian).
     */
    void loadBunny(WorldEditor edit) {
        string directory = "/work/data/bunny/";

        int y = 1;
        ushort[512*512] data;
        const N=5;

        void blatSlice() {
            for(int z=0;z<512; z++)
            for(int x=0;x<512; x++)
            {
                ushort value = data[x+z*512];
                if(value >= 45000) {
                    auto p = ivec3(300+x*N, 362*N-y*N, 300+(512*N-z*N));
                    //edit.setVoxel(V_SNOW, x, 361-y, 512-z);
                    edit.rectangle(p, p+N, 2, V_SNOW);
                }
            }
        }
        void loadSlice() {
            scope f = File(directory~y.to!string);
            f.rawRead(data);
            blatSlice();
        }

        while(y<=361) {
            loadSlice();
            y++;
            writefln("%s / %s", y, 361); flushConsole();
        }
    }
}

