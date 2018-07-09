module gen;
/**
 *
 */
import blockie.all;
import blockie.generate.all;

import core.sys.windows.windows;
import core.runtime : Runtime;

extern(Windows)
int WinMain(HINSTANCE theHInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
	int result = 0;
	Generator app;
	Throwable exception;
	try{
		Runtime.initialize();

		app = new Generator();
		app.run();
	}catch(Throwable e) {
	    exception = e;
		log("exception: %s", e.msg);
	}finally{
		flushLog();
		flushStdErrOut();
		app.destroy();
		if(exception) {
		    MessageBoxA(null, exception.toString().toStringz, "Error", MB_OK | MB_ICONEXCLAMATION);
        	result = -1;
		}
		Runtime.terminate();
	}
	return result;
}

final class Generator {
    this() {

    }
    void destroy() {

    }
    void run() {
//        Chunk ch  = Chunk.airChunk(ivec3(0,0,0));
//        auto view = ch.beginEdit();
//        setOctreeVoxel(view, 1, 0,0,0);
//        writefln("---------------------------");
//        setOctreeVoxel(view, 0, 0,0,0);

//        generateWorld(new TestScene1());
//        generateWorld(new TestScene2());
//        generateWorld(new TestScene3());
//        generateWorld(new TestScene4());
//        //generateWorld(new TestScene4b());
//        //generateWorld(new TestScene4c());
//        generateWorld(new TestScene5());
//        generateWorld(new TestScene6());
        generateWorld(new TestScene7());

        writefln("maxBranches        = %s", maxBranches);
        writefln("maxLeaves          = %s (%s bits)", maxLeaves, bitsRequiredToEncode(maxLeaves));
        writefln("maxVoxelsLength    = %s", maxVoxelsLength);
        writefln("numChunksOptimised = %s", numChunksOptimised);
    }
    void generateWorld(WorldGen gen) {
        auto w = gen.getWorld();
        writefln("Generating %s", w);
        flushStdErrOut();
        auto builder = new WorldBuilder();
        gen.build(builder);
        auto chunks = builder.getChunks();
        calculateAirNibbles(chunks);
        auto airChunks = generateAirChunks(chunks);
        saveScene(w, chunks, airChunks);
    }
    void saveScene(World w, Chunk[] chunks, Chunk[] airChunks) {
        saveWorld(w);

        foreach(c; chunks) {
            saveChunk(w, c);
        }

        saveAirChunks(w,
            airChunks.map!(it=>AirChunk(it.pos,
                                        it.root.flags.distX,
                                        it.root.flags.distY,
                                        it.root.flags.distZ)
                                        )
                     .array
        );
    }
}

