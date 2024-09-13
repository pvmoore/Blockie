module blockie.model.ChunkStorage;
///
/// Cache chunks and handle loading and saving.
///
import blockie.model;

final class ChunkStorage {
private:
    World world;
    ChunkSerialiser serialiser;
    bool running = true;
    Semaphore msgSemaphore, shutdownReady;
    IQueue!EventMsg messages;
    string directory;
    Chunk[chunkcoords] chunks;
    FileLogger logger;

public:
    ulong bytesWritten;
    ulong bytesRead;
    Model model;

    this(World w, Model model) {
        this.world         = w;
        this.model         = model;
        this.logger        = new FileLogger(".logs/storage.log")
            .setEagerFlushing(true);
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
        logger.log("ChunkStorage: Waiting for message thread...");
        shutdownReady.wait();
        logger.log("ChunkStorage: Message thread finished");

        auto airChunks = chunks.values
                               .filter!(it=>it.isAir)
                               .array;

        serialiser.saveAirChunks(airChunks);
        serialiser.destroy();
        logger.log("ChunkStorage: Saved %s air chunks", airChunks.length);
        logger.close();
    }
    Chunk blockingGet(chunkcoords coords) {
        auto ptr = coords in chunks;
        if(ptr) return *ptr;

        auto c = model.makeChunk(coords);
        chunks[coords] = c;
        ulong bytes = serialiser.load(c);
        bytesRead += bytes;
        getEvents().fire(EventMsg(EventID.STORAGE_READ, bytesRead.as!double/ (1024*1024)));
        getEvents().fire(EventMsg(EventID.CHUNK_LOADED, c));
        return c;
    }
    Chunk asyncGet(chunkcoords coords) {
        auto ptr = coords in chunks;
        if(ptr) return *ptr;

        auto ch = model.makeChunk(coords);
        throwIf(ch.getVersion()!=0);
        chunks[coords] = ch;

        getEvents().fire(EventMsg(EventID.CHUNK_ACTIVATED, ch));
        return ch;
    }
private:
    void initialise() {
        logger.log("ChunkStorage: Initialising");
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
        logger.log("ChunkStorage: Loaded %s air chunks", chunks.length);
    }
    ///
    /// Runs on ChunkStorage thread.
    ///
    void loop() {
        logger.log("ChunkStorage: Message thread running");

        void fetchChunk(Chunk c) {
            logger.log("Fetching chunk %s", c);
            ulong bytes = serialiser.load(c);
            logger.log("bytes = %s", bytes);
            bytesRead += bytes;
            getEvents().fire(EventMsg(EventID.STORAGE_READ, bytesRead.as!double / (1024*1024)));
            getEvents().fire(EventMsg(EventID.CHUNK_LOADED, c));
            logger.log("done");
        }
        void saveChunk(Chunk c) {
            logger.log("ChunkStorage: Save chunk %s", c);
            ulong bytes = serialiser.save(c);
            bytesWritten += bytes;
            getEvents().fire(EventMsg(EventID.STORAGE_WRITE, bytesWritten.as!double / (1024*1024)));
        }
        void handleMessage(EventMsg msg) {
            logger.log("ChunkStorage: Processing event %s chunk:%s", msg.id, msg.get!Chunk);
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
            logger.log("end msg");
        }

        while(true) {
            try{
                msgSemaphore.wait();
                if(!running) break;

                auto msg = messages.pop();
                handleMessage(msg);

            }catch(Throwable e) {
                logger.log("ChunkStorage: %s", e.toString);
            }
        }

        logger.log("ChunkStorage: Message thread closing down");
        logger.log("ChunkStorage: Processing remaining messages");
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

