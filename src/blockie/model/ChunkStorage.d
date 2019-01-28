module blockie.model.ChunkStorage;
///
/// Cache chunks and handle loading and saving.
///
import blockie.all;

final class ChunkStorage {
private:
    World world;
    ChunkSerialiser serialiser;
    bool running = true;
    Semaphore msgSemaphore, shutdownReady;
    IQueue!EventMsg messages;
    string directory;
    Chunk[chunkcoords] chunks;

public:
    ulong bytesWritten;
    ulong bytesRead;
    Model model;

    this(World w, Model model) {
        this.world         = w;
        this.model         = model;
        this.serialiser    = model.makeChunkSerialiser(w);
        this.directory     = "data/" ~ w.name ~ "/";
        this.msgSemaphore  = new Semaphore;
        this.shutdownReady = new Semaphore;
        this.messages      = makeSPSCQueue!EventMsg(1024*1024);

        initialise();
    }
    void destroy() {
        running = false;
        msgSemaphore.notify();
        log("ChunkStorage: Waiting for message thread...");
        shutdownReady.wait();
        log("ChunkStorage: Message thread finished");

        auto airChunks = chunks.values
                               .filter!(it=>it.isAir)
                               .array;

        serialiser.saveAirChunks(airChunks);
        serialiser.destroy();
        log("ChunkStorage: Saved %s air chunks", airChunks.length);
    }
    Chunk blockingGet(chunkcoords coords) {
        auto ptr = coords in chunks;
        if(ptr) return *ptr;

        auto c = model.makeChunk(coords);
        chunks[coords] = c;
        ulong bytes = serialiser.load(c);
        bytesRead += bytes;
        getDiskMonitor().setValue(0, bytesRead/MB);
        getEvents().fire(EventMsg(EventID.CHUNK_LOADED, c));
        return c;
    }
    Chunk asyncGet(chunkcoords coords) {
        auto ptr = coords in chunks;
        if(ptr) return *ptr;

        auto ch = model.makeChunk(coords);
        assert(ch.version_==0);
        chunks[coords] = ch;

        getEvents().fire(EventMsg(EventID.CHUNK_ACTIVATED, ch));
        return ch;
    }
private:
    void initialise() {
        log("ChunkStorage: Initialising");
        /// Start the message processing thread
        Thread t = new Thread(&loop);
        t.isDaemon = true;
        t.name = "ChunkStorage";
        t.start();

        /// Subscribe to events
        getEvents().subscribe(
            "ChunkStorage",
            EventID.CHUNK_ACTIVATED |
            EventID.CHUNK_DEACTIVATED |
            EventID.CHUNK_EDITED,
            messages,
            msgSemaphore
        );

        /// Load the air chunks
        foreach(ch; serialiser.loadAirChunks()) {
            chunks[ch.pos] = ch;
        }
        log("ChunkStorage: Loaded %s air chunks", chunks.length);
    }
    ///
    /// Runs on ChunkStorage thread.
    ///
    void loop() {
        log("ChunkStorage: Message thread running");

        void fetchChunk(Chunk c) {
            ulong bytes = serialiser.load(c);
            bytesRead += bytes;
            getDiskMonitor().setValue(0, bytesRead/MB);
            getEvents().fire(EventMsg(EventID.CHUNK_LOADED, c));
        }
        void saveChunk(Chunk c) {
            log("ChunkStorage: Save chunk %s", c);
            ulong bytes = serialiser.save(c);
            bytesWritten += bytes;
            getDiskMonitor().setValue(1, bytesWritten/MB);
        }
        void handleMessage(EventMsg msg) {
            //log("ChunkStorage: Processing event %s", msg);
            switch(msg.id) {
                case EventID.CHUNK_ACTIVATED:
                    fetchChunk(msg.get!Chunk);
                    break;
                case EventID.CHUNK_DEACTIVATED:
                    break;
                case EventID.CHUNK_EDITED:
                    saveChunk(msg.get!Chunk);
                    break;
                default:
                    break;
            }
        }

        while(true) {
            try{
                msgSemaphore.wait();
                if(!running) break;

                auto msg = messages.pop();
                handleMessage(msg);

            }catch(Throwable e) {
                log("ChunkStorage: %s", e.toString);
            }
        }

        log("ChunkStorage: Message thread closing down");
        log("ChunkStorage: Processing remaining messages");
        EventMsg[1000] msgs;
        uint num;
        do{
            num = messages.drain(msgs);
            if(num>0) {
                for (auto i=0;i<num;i++) {
                    handleMessage(msgs[i]);
                }
            }
        }while(num>0);
        shutdownReady.notify();
    }
}

