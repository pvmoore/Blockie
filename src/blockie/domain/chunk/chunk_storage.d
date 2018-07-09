module blockie.domain.chunk.chunk_storage;
/**
 *  Cache chunks and handle loading and saving.
 */
import blockie.all;

align(1) struct AirChunk { align(1):
    ivec3 pos;
    ubyte distX;
    ubyte distY;
    ubyte distZ;
}
static assert(AirChunk.sizeof==15);

final class ChunkStorage {
private:
    const double MB = 1024*1024;
    World world;
    bool running = true;
    Semaphore semaphore;
    IQueue!EventMsg messages;
    string directory;
    Chunk[ivec3] chunks;
public:
    ulong bytesWritten;
    ulong bytesRead;

    this(World w) {
        this.world     = w;
        this.directory = "data/" ~ w.name ~ "/";
        this.semaphore = new Semaphore;
        this.messages  = makeSPSCQueue!EventMsg(1024*1024);
        initialise();
    }
//    void destroy() {
//        auto air = chunks.values
//                         .filter!(it=>it.isAir)
//                         .map!(it=>AirChunk(it.pos, it.root.flags.distance))
//                         .array;
//
//        saveAirChunks(world, air);
//    }
    Chunk get(ivec3 i) {
        auto ptr = i in chunks;
        if(ptr) return *ptr;

        auto ch = Chunk.airChunk(i);
        chunks[i] = ch;

        getEvents().fire(EventMsg(EventID.CHUNK_ACTIVATED, ch));
        return ch;
    }
private:
    void initialise() {
        // start the message processing thread
        Thread t = new Thread(&loop);
        t.isDaemon = true;
        t.name = "ChunkStorage";
        t.start();

        // subscribe to events
        getEvents().subscribe(
            "ChunkStorage",
            EventID.CHUNK_ACTIVATED |
            EventID.CHUNK_DEACTIVATED,
            messages,
            semaphore
        );

        // load the air chunks
        foreach(c; loadAirChunks(world)) {
            auto chunk = Chunk.airChunk(c.pos);
            chunk.optimisedRoot.flags.distX = c.distX;
            chunk.optimisedRoot.flags.distY = c.distY;
            chunk.optimisedRoot.flags.distZ = c.distZ;
            chunks[c.pos] = chunk;
        }
        log("Loaded %s air chunks", chunks.length);
    }
    @Async
    void loop() {
        log("ChunkStorage message thread running");

        void fetchChunk(Chunk c) {
            if(exists(directory ~ c.filename)) {
                ulong bytes = loadChunk(world, c);
                bytesRead += bytes;
                getDiskMonitor().setValue(0, bytesRead/MB);
                getEvents().fire(EventMsg(EventID.CHUNK_UPDATED, c));
            }
        }

        while(true) {
            try{
                semaphore.wait();
                if(!running) return;

                auto msg = messages.pop();
                    //log("ChunkStorage: Processing event %s", msg);

                    switch(msg.id) {
                    case EventID.CHUNK_ACTIVATED:
                        fetchChunk(msg.get!Chunk);
                        break;
                    case EventID.CHUNK_DEACTIVATED:
                        break;
                    default: break;
                }
            }catch(Throwable e) {
                log("ChunkStorage: %s", e.toString);
            }
        }
    }
}

