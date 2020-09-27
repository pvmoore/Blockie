module blockie.generate.testscene7_hgt;

import blockie.all;
import blockie.generate.all;
/**
 *
 */
final class TestScene7_hgt : SceneGenerator {
    const uint xsize   = 1024*3;
    const uint ysize   = 1024*2;
    const uint zsize   = 1024*3;

    @Implements("WorldGen")
    World getWorld() {
        World w = new World("Test Scene 7 - HGT");

        w.sunPos = vec3(1024, 1024*3, 1024);

        auto cpos = vec3(1630.00, 1634.98, 4509.35);

        w.camera = new Camera3D(
            cpos,                                // position
            cpos+vec3(0.03, -0.40, -0.92)     // focal point
        );
        w.camera.fovNearFar(60.degrees, 10, 100000);
        return w;
    }
    @Implements("WorldGen")
    void build(WorldEditor edit) {

        edit.startTransaction();

        loadHGT(edit);

        edit.commitTransaction();

        log("maxVoxelsLength = %s", maxVoxelsLength);
        log("maxBranches = %s", maxBranches);
        log("maxLeaves   = %s", maxLeaves);
    }
private:
    /**
     *  3601*3601 cells (1 inch)
     *  Each cell is ushort (big-endian)
     */
    void loadHGT(WorldEditor edit) {
        auto hgt = HGT.read("/temp/heightmaps/N47E006.hgt");
        expect(hgt.inches==3);
        expect(hgt.data.length==3601*3601);

        for(auto z=0; z<3601; z++) {
            for(auto x=0; x<3601; x++) {
                int height = hgt[x,z];
                //int height = cast(int)((hgt[x,z]*30000) / 65535.0);
                //writefln("%s", height);
                for(auto y=0; y<height; y++) {
                    edit.setVoxel(worldcoords(x, y, z), V_ROCK1);
                }
            }
            writefln("%s / %s", z, 3601); flushConsole();
        }
    }
}

