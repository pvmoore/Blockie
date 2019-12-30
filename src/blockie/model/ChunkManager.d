module blockie.model.ChunkManager;

import blockie.all;
///
/// Manage chunks in a scene and data transfer to GPU.
///
final class ChunkManager {
private:
    const uint VIEW_WINDOW_X    = 25;
    const uint VIEW_WINDOW_Y    = 8;
    const uint VIEW_WINDOW_Z    = 25;

    const uint3 VIEW_WINDOW     = uint3(VIEW_WINDOW_X,VIEW_WINDOW_Y,VIEW_WINDOW_Z);
    const int3 HALF_VIEW_WINDOW = int3(VIEW_WINDOW_X/2,VIEW_WINDOW_Y/2,VIEW_WINDOW_Z/2);
    const int3 VIEW_WINDOW_MUL  = int3(1,VIEW_WINDOW_X,VIEW_WINDOW_X*VIEW_WINDOW_Y);
    const uint VIEW_WINDOW_HMUL = VIEW_WINDOW_X*VIEW_WINDOW_Y*VIEW_WINDOW_Z;

    static final class ChunkInfo {
        Chunk chunk;
        uint offset;
        uint size;
        bool onGPU;
        bool flyweight;
    }

    struct { /// messages
        IQueue!EventMsg messages;
        EventMsg[1000] tempMessages;
        Chunk[1000] tempChunks;
    }
    struct { /// stats
        ulong totalGPUWrites;
        ulong totalCameraMoveUpdateTime;
        ulong totalChunkUpdateTime;
        ulong numCameraMoves;
        ulong numChunkUpdateBatches;
        uint numOnGPU;
        uint numActive;
        uint numFlyweight;
    }

    World world;
    SceneChangeListener listener;
    ChunkStorage storage;

    chunkcoords lastccp;
    chunkcoords base;
    worldcoords worldMin, worldMax;

    ChunkInfo[chunkcoords] chunks;

    uint[VIEW_WINDOW_HMUL]      chunkData;
    ChunkInfo[VIEW_WINDOW_HMUL] currentGrid;
    ChunkInfo[VIEW_WINDOW_HMUL] tempGrid;

    VBOMemoryManager voxelsMM;
    VBOMemoryManager chunksMM;
public:
    interface SceneChangeListener {
        void boundsChanged(uint3 chunksDim, worldcoords min, worldcoords max);
    }

    this(SceneChangeListener listener,
         World world,
         VBOMemoryManager voxelsVboMM,
         VBOMemoryManager chunksVboMM)
    {
        this.messages = makeSPSCQueue!EventMsg(1024*1024);
        this.listener = listener;
        this.world    = world;
        this.voxelsMM = voxelsVboMM;
        this.chunksMM = chunksVboMM;
        version(MODEL1) {
            this.storage  = new ChunkStorage(world, new Model1);
        } else version(MODEL2) {
            this.storage  = new ChunkStorage(world, new Model2);
        } else version(MODEL3) {
            this.storage  = new ChunkStorage(world, new Model3);
        } else version(MODEL4) {
            this.storage  = new ChunkStorage(world, new Model4);
        } else version(MODEL5) {
            this.storage  = new ChunkStorage(world, new Model5);
        } else version(MODEL1A) {
            this.storage  = new ChunkStorage(world, new Model1a);
        } else assert(false);

        getEvents().subscribe("ChunkManager", EventID.CHUNK_LOADED | EventID.CHUNK_EDITED, messages);
        initialise();
    }
    void destroy() {
        storage.destroy();
    }
    void afterUpdate() {
        bool chunkDataChanged = false;

        /// 1) check the camera position
        chunkcoords ccp = (world.camera.position / CHUNK_SIZE).floor().to!int;
        if(ccp != lastccp) {
            chunkDataChanged = true;
            cameraMovedTo(ccp);
        }

        /// 2) handle chunk update messages
        auto numMsgs = messages.drain(tempMessages);
        if(numMsgs>0) {
            for(auto i=0;i<numMsgs;i++) {
                tempChunks[i] = tempMessages[i].get!Chunk;
            }
            chunkDataChanged |= chunksUpdated(tempChunks[0..numMsgs]);
        }

        if(chunkDataChanged) {
            writeChunkData();
        }

        getGPUIOMonitor().setValues(
            totalGPUWrites/MB,
            voxelsMM.numBytesUsed/MB,
            chunksMM.numBytesUsed/KB,
            (totalCameraMoveUpdateTime/cast(double)numCameraMoves)/1000000.0,
            (totalChunkUpdateTime/cast(double)numChunkUpdateBatches)/1000000.0
        );

        getChunksMonitor().setValues(
            chunks.length,
            numOnGPU,
            numActive,
            numFlyweight
        );
    }
private:
    void initialise() {
        log("ChunkManager: Initialising {");

        lastccp = (world.camera.position / CHUNK_SIZE).floor().to!int;
        log("\t\tCamera pos       = %s", world.camera.position);
        log("\t\tCamera chunk pos = %s", lastccp);

        base = lastccp - HALF_VIEW_WINDOW;
        log("\t\tBounds(chunks)   = %s %s", base, (base+(VIEW_WINDOW.to!int)));
        flushLog();

        StopWatch watch; watch.start();

        updateWorldBB(base*CHUNK_SIZE, (base+(VIEW_WINDOW.to!int))*CHUNK_SIZE);

        voxelsMM.bind();

        ///Activate all DIAMETER^^3 chunks
        uint index = 0;
        for(auto z=0; z<VIEW_WINDOW.z; z++)
        for(auto y=0; y<VIEW_WINDOW.y; y++)
        for(auto x=0; x<VIEW_WINDOW.x; x++) {
            auto p  = base + ivec3(x,y,z);
            auto ci = activateChunk(p);

            ci.onGPU = true;
            numOnGPU++;

            ci.offset = cast(uint)voxelsMM.write(ci.chunk.getVoxels(), 4);
            ci.size   = cast(uint)ci.chunk.getVoxelsLength();

            totalGPUWrites    += ci.size;
            currentGrid[index] = ci;

            index++;
        }
        writeChunkData();

        watch.stop();
        log("\tWritten %s bytes to GPU", totalGPUWrites);
        log("\t\ttook %s millis", watch.peek().total!"nsecs"/1000000.0);
        log("}");
        flushLog();
    }
    ///
    /// The camera has moved to a different chunk. Update
    /// the visible window of voxelOffsets. Handle chunks
    /// entering and leaving the window.
    ///
    /// Possible future optimisation:
    ///     Increase the window dimension by 1 and update
    ///     this in a background thread so that we have
    ///     the chunks ready for when the camera actually
    ///     reaches that position.
    ///
    void cameraMovedTo(chunkcoords ccp) {
        log("ChunkManager: Mamera moved {");
        log("\t\tfrom %s", lastccp);
        log("\t\tto   %s", ccp);
        StopWatch watch; watch.start();

        numCameraMoves++;
        chunkcoords soffset = lastccp-ccp;
        lastccp = ccp;

        uint3 uoffset = soffset.to!uint;
        int sadd      = (soffset*VIEW_WINDOW_MUL).hadd;

        tempGrid[] = currentGrid[];

        chunkcoords oldBase = base;
        base = ccp - HALF_VIEW_WINDOW;

        updateWorldBB(base*CHUNK_SIZE, (base+VIEW_WINDOW.to!int)*CHUNK_SIZE);

        voxelsMM.bind();

        int index = 0;
        for(uint z=0; z<VIEW_WINDOW.z; z++)
        for(uint y=0; y<VIEW_WINDOW.y; y++)
        for(uint x=0; x<VIEW_WINDOW.x; x++) {
            uint3 from  = uint3(x,y,z) - uoffset;
            uint3 to    = uint3(x,y,z) + uoffset;
            //log("here=%s from=%s to=%s", here, from, to); flushLog();

            if(to.anyGTE(VIEW_WINDOW)) {
                /// This chunk is moving out of bounds
                chunkcoords pos = oldBase+ivec3(x,y,z);
                //log("going oob: %s %s", ivec3(x,y,z),pos);

                auto ci = getChunkInfo(pos);
                ci.onGPU = false;
                numOnGPU--;
                voxelsMM.free(ci.offset, ci.size);
            }

            if(from.anyGTE(VIEW_WINDOW)) {
                /// This offset needs a new chunk
                chunkcoords pos = base+ivec3(x,y,z);
                //log("coming in: %s %s", ivec3(x,y,z),pos);
                auto ci = activateChunk(pos);
                ci.onGPU = true;
                numOnGPU++;

                ci.offset = cast(uint)voxelsMM.write(ci.chunk.getVoxels(), 4);
                auto length = cast(uint)ci.chunk.getVoxelsLength();
                totalGPUWrites += length;
                ci.size = length;

                currentGrid[index] = ci;
            } else {
                currentGrid[index] = tempGrid[index-sadd];
            }
            index++;
        }

        watch.stop();
        totalCameraMoveUpdateTime += watch.peek().total!"nsecs";

        log("\t\ttook %s millis", watch.peek().total!"nsecs"/1000000.0);
        log("}");
    }
    bool chunksUpdated(Chunk[] chunks) {
        log("Chunks updated");
        StopWatch w; w.start();
        bool chunkDataChanged = false;

        voxelsMM.bind();

        foreach(c; chunks) {
            ChunkInfo ci = getChunkInfo(c.pos);
            if(!ci) continue;

            if(ci.onGPU) {

//                log("update offset %s size %s to %s (voxelsOffset=%s)",
//                    ci.offset, ci.size, c.voxels.length, i);

                voxelsMM.free(ci.offset, ci.size);

                ci.offset = cast(uint)voxelsMM.write(c.voxels, 4);
                ci.size   = cast(uint)c.voxels.length;
                totalGPUWrites += ci.size;

                chunkDataChanged = true;
            }
        }

        w.stop();
        totalChunkUpdateTime += w.peek().total!"nsecs";
        numChunkUpdateBatches++;
        log("Total bytes written to GPU: %s", totalGPUWrites);
        flushLog();
        return chunkDataChanged;
    }
    void updateWorldBB(worldcoords min, worldcoords max) {
        worldMin = min;
        worldMax = max;
        listener.boundsChanged(VIEW_WINDOW, min, max);
    }
    void writeChunkData() {
        chunksMM.bind();
        ulong numBytes = chunkData.length*uint.sizeof;
        /// free the existing region if it exists
        if(chunksMM.numBytesUsed>0) {
            chunksMM.free(0, numBytes);
        }
        /// update chunkData
        uint* dest = chunkData.ptr;
        foreach(ci; currentGrid) {
            expect(ci.offset%4==0);
            *dest++ = ci.offset;
        }
        /// write chunkData to VBO
        totalGPUWrites += numBytes;
        expect(0==chunksMM.write(chunkData, 4));
    }
//    uint getGridIndex(Chunk c) {
//        ivec3 p = c.pos-base;
//        //if(p.anyLT(0) || p.anyGTE(DIAMETER)) return -1;
//        //return p.x + p.y*DIAMETER + p.z*DIAMETER2;
//        return (p*VIEW_WINDOW_MUL).hadd;
//    }
    ChunkInfo getChunkInfo(chunkcoords p) {
        ChunkInfo* ptr = p in chunks;
        return ptr ? *ptr : null;
    }
    ChunkInfo activateChunk(chunkcoords p) {
        auto ptr = (p in chunks);
        ChunkInfo ci;
        if(ptr) {
            ci = *ptr;
        } else {
            ci = new ChunkInfo;
            ci.chunk = storage.asyncGet(p);
            ci.flyweight = true;
            numFlyweight++;
            chunks[p] = ci;
        }
        if(ci.flyweight) {
            numActive++;
            numFlyweight--;
            ci.flyweight = false;
        }
        return ci;
    }
//    void deactivateChunk(chunkcoords p) {
//        ChunkInfo c = chunks[p];
//        if(c.flyweight) return;
//
//        c.flyweight = true;
//        numActive--;
//        numFlyweight++;
//
//        getEvents().fire(EventMsg(EventID.CHUNK_DEACTIVATED, c.chunk));
//    }
}

