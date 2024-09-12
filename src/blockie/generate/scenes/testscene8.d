module blockie.generate.scenes.testscene8;

import blockie.generate.all;

final class TestScene8 : SceneGenerator {
    ImprovedPerlin noise;
    const uint width   = 1024*1;    // x
    const uint height  = 1024*1;    // y
    const uint breadth = 1024*1;    // z

    this() {
        this.noise = new ImprovedPerlin(31);
    }

    @Implements("WorldGen")
    World getWorld() {
        World w = new World("Test Scene 8");

        w.sunPos = vec3(512, 1024*10, 1024);

        w.camera = new Camera3D(
            vec3(1200,1100,1000), // position
            vec3(0,0,0)          // focal point
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
                    //80 * noise.get(
                    //    0.8*cast(float)x/width,
                    //    0.8*cast(float)z/breadth
                    //)
                    //+
                    420 * noise.get(
                        1.9*cast(float)x/width,
                        1.9*cast(float)z/breadth
                    )
                    //+
                    //20 * noise.get(
                    //    8.0*cast(float)x/width,
                    //    8.0*cast(float)z/breadth
                    //)
                    //+ 15 * noise.get(
                    //    40.0*cast(float)x/width,
                    //    40.0*cast(float)z/breadth
                    //)
                    //+
                    //10 * noise.get(
                    //    60.0*cast(float)x/width,
                    //    60.0*cast(float)z/breadth
                    //)
                ;
                uint h = cast(int)(hf + height/2);

                uint hmin = h-5;
                uint snowline  = height/2+50;
                uint waterline = height/2;
                uint sandline  = waterline + 15;

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
    }
}
