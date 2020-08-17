module blockie.generate.landscapeworld;

import blockie.generate.all;
/**
 * Creates a random flat landscape with smooth hills.
 * 1. Midpoint displacement algorithm.
 * 2. Midpoint displacement using squares and diamonds.
 *
 *  Chunk size:     7           8           9
 *  LDC:         902.00ms    926.00ms   1036.00ms
 *  CL:            1.41ms      1.51ms      1.70ms
 *  Data:      15,355,829  15,345,879  15,344,929
 */
 /+
final class LandscapeWorld : Async!World {
private:
    World w;
    uint xsize, ysize, zsize, xzsize;
    void delegate(int percent,string msg) progressCallback;
public:
    this(uint x, uint y, uint z) {
        this.xsize  = x;
        this.ysize  = y;
        this.zsize  = z;
        this.xzsize = xsize*zsize;
    }
    void setProgressCallback(void delegate(int percent,string msg) c) {
        progressCallback = c;
    }
    World run() {
        progressCallback(0, "Landscaping...");
        StopWatch watch; watch.start();
        uint chunksX = xsize/CHUNK_SIZE;
        uint chunksY = ysize/CHUNK_SIZE;
        uint chunksZ = zsize/CHUNK_SIZE;

        w = new World("Landscape World", chunksX,chunksY,chunksZ);

        uint size   = 512+1;
        float scale = 10;
        auto diamondSquare = new DiamondSquare(size, scale, size-1);
        auto heights = diamondSquare.generate();
        //writefln("%s", diamondSquare);

        auto edit = w.edit();

        for(auto z=0; z<size; z++) {
            for(auto x=0; x<size; x++) {
                int y = ysize/2 + cast(int)heights[x+z*size]*1;
                //w.setVoxel(1, x, y, z);
                //w.setVoxelStack(1, x, y, z);

                for(auto yy=y; yy>y-10; yy--) {
                    edit.setVoxel(V_ROCK1, x,yy,z);
                }
            }
            progressCallback(5+(z*90)/zsize, "");
        }

        progressCallback(95, "Optimising...");
        edit.optimise(w.chunks)
            .commit();

        progressCallback(97, "Initialising camera");

        w.sunPos = Vector3(1000,
                           10000,
                           -700);

        w.camera = new Camera3D(
            Dimension(0,0),
            Vector3(-458.37506, 695.84143, 580.04718), // pos
            Vector3(0.07265, 0.83075, -0.13143),      // up
            Vector3(xsize/2,ysize/2,0) // focal point
        );
        w.camera.fovNearFar(70, 10, 1000);
        writefln("camera=%s", w.camera);

        progressCallback(100, "Done");

        writefln("Created %s", w);
        watch.stop();
        writefln("Took %f seconds to init world", watch.peek().nsecs/1000000000.0);
        flushStdErrOut();
        return w;
    }
}

+/
