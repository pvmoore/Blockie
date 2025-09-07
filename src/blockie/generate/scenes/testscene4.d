module blockie.generate.scenes.testscene4;

import blockie.generate.all;

final class TestScene4 : SceneGenerator {
    ImprovedPerlin noise;
    const uint width   = 1024*15;   // x
    const uint height  = 1024*2;    // y
    const uint breadth = 1024*15;   // z

    this() {
        this.noise = new ImprovedPerlin(0);
    }

    @Implements("WorldGen")
    World getWorld() {
        World w = new World("Test Scene 4");

        w.sunPos = float3(0, 10000, 0);

        w.camera = new Camera3D(
            float3(4096.00, 2047.72, 7649.85),       // position
            float3(1024*4, 1024, 1024*4) // focal point
        );
        w.camera.fovNearFar(60.degrees, 10, 100000);
        return w;
    }
    @Implements("WorldGen")
    void build(WorldEditor edit) {

        edit.startTransaction();

        for(auto x=0; x<width; x++) {
            for(auto z=0; z<breadth; z++) {
                float hf =
                    1000 * noise.get(
                        1.0*cast(float)x/width,
                        1.0*cast(float)z/breadth
                    ) +
                    500 * noise.get(
                        5.0*cast(float)x/width,
                        5.0*cast(float)z/breadth
                    ) +
                    250 * noise.get(
                        15.0*cast(float)x/width,
                        15.0*cast(float)z/breadth
                    ) +
                    125 * noise.get(
                        40.0*cast(float)x/width,
                        40.0*cast(float)z/breadth
                    )+
                    25 * noise.get(
                        60.0*cast(float)x/width,
                        60.0*cast(float)z/breadth
                    );
                uint h = cast(int)(hf + height/2);
                uint hmin = h-20;
                uint snowline  = height/2+320;
                uint waterline = height/2;
                uint sandline  = waterline + 25;
                while(h>hmin) {
                    ubyte v = V_EARTH1;
                    if(h<waterline) v = V_WATER;
                    if(h>waterline && h<sandline) v = V_SAND;
                    if(h>snowline) {
                        v = V_SNOW;
//                        if(noise.get(
//                            10.0*cast(float)x/width,
//                            10.0*cast(float)z/breadth,
//                            10.0*cast(float)h/height)>0) {
//                            v = V_SNOW;
//                        } else {
//                            v = V_ROCK1;
//                        }
                    }
                    edit.setVoxel(worldcoords(x,h,z), v);
                    h--;
                }
            }
        }

        edit.commitTransaction();

        log("maxVoxelsLength = %s", maxVoxelsLength);
        log("maxBranches = %s", maxBranches);
        log("maxLeaves   = %s", maxLeaves);
    }
}

