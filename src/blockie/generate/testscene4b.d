module blockie.generate.testscene4b;

import blockie.generate.all;
/**
 *  Resolution: 1920x1080 (-26*2y)
 *
 *  Chunk   Data            Render  (Max len,br,lv)
 *  Size                    Time
 *  6 r=1   62,058,852      [4.73,3.67,0.12]  (62668,962,2412)
 *          67,561,352      [4.62,3.60,0.12]  (62643,954,2412)
 *         112,462,952      4.10ms  (63093,916,2412)
 *
 *  7 r=1   61,368,780      [4.30,3.34,0.12]  (260202,3998,10061)
 *          62,030,180      [4.20,3.23,0.12]  (260177,3990,10061)
 *          67,532,680      [4.22,3.29,0.12]  (260602,3950,10061)
 *         112,434,280      3.99ms  (267752,3786,10061)
 *         475,254,680      5.34ms  (340102,3099,10061)
 *
 *  8       61,288,496      [4.30,3.34,0.12]  (857236,13328,32860)
 *          61,365,196      [4.20,3.22,0.12]  (857311,13324,32860)
 *          62,026,596      [4.25,3.29,0.12]  (858036,13298,32860)
 *          67,529,096      [4.69,3.71,0.12]  (866036,13174,32860)
 *         112,430,696      5.24ms  (941986,12636,32860)
 *
 *  9       61,279,984      3.86ms  (2338381,36891,88505)
 *          61,288,048      3.70ms  (2338456,36887,88505)
 *          61,364,748      3.70ms  (2339456,36871,88505)
 *          62,026,148      4.07ms  (2348656,36791,88505)
 *          67,528,648      5.55ms  (2429531,36442,88505)
 *
 *  10      61,279,392      4.28ms  (8454100,133786,319339)
 *          61,279,992      3.97ms  (8454175,133782,319339)
 *          61,287,992      4.01ms  (8455175,133766,319339)
 *          61,364,692      4.56ms  (8464750,133701,319339)
 *          62,026,092      5.93ms  (8546750,133397,319339)
 */
final class TestScene4b : SceneGenerator {
    ImprovedPerlin noise;
    const uint width   = 1024*8;    // x
    const uint height  = 1024*2;    // y
    const uint breadth = 1024*8;    // z

    this() {
        this.noise = new ImprovedPerlin(4);
    }

    @Implements("WorldGen")
    World getWorld() {
        World w = new World("Test Scene 4b");

        w.sunPos = vec3(0, 10000, 0);

        w.camera = new Camera3D(
            vec3(4096.00, 2047.72, 7649.85),       // position
            vec3(1024*4, 1024, 1024*4) // focal point
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
                    )
                    + 500 * noise.get(
                        5.0*cast(float)x/width,
                        5.0*cast(float)z/breadth
                    )
                    + 250 * noise.get(
                        12.0*cast(float)x/width,
                        12.0*cast(float)z/breadth
                    )
//                    + 125 * noise.get(
//                        40.0*cast(float)x/width,
//                        40.0*cast(float)z/breadth
//                    )
//                    + 25 * noise.get(
//                        60.0*cast(float)x/width,
//                        60.0*cast(float)z/breadth
//                    )
                    ;
                uint h = cast(int)(hf + height/2);
                uint hmin = h-5;
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

