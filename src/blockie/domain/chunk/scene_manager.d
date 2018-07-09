module blockie.domain.chunk.scene_manager;

import blockie.all;
/**
 *  Manage chunks in a scene and data transfer to GPU.
 */
interface ChunkUpdateListener {
    void setBounds(uvec3 chunksDim, ivec3 min, ivec3 max);
}
final class SceneManager {
private:
    const double KB          = 1024;
    const double MB          = 1024*1024;
    const uint VIEW_WINDOW_X = 50/(CHUNK_SIZE/512);  // 50*512 = 25600
    const uint VIEW_WINDOW_Y = 16/(CHUNK_SIZE/512);  // 16*512 = 8192
    const uint VIEW_WINDOW_Z = 50/(CHUNK_SIZE/512);  // 50*512 = 25600
    const uvec3 VIEW_WINDOW      = uvec3(VIEW_WINDOW_X,VIEW_WINDOW_Y,VIEW_WINDOW_Z);
    const ivec3 HALF_VIEW_WINDOW = ivec3(VIEW_WINDOW_X/2,VIEW_WINDOW_Y/2,VIEW_WINDOW_Z/2);
    const ivec3 VIEW_WINDOW_MUL  = ivec3(1,VIEW_WINDOW_X,VIEW_WINDOW_X*VIEW_WINDOW_Y);
    const uint VIEW_WINDOW_HMUL  = VIEW_WINDOW_X*VIEW_WINDOW_Y*VIEW_WINDOW_Z;

    IQueue!EventMsg messages;
    EventMsg[1000] tempMessages;
    Chunk[1000] tempChunks;
    World world;
    ChunkUpdateListener listener;
    ChunkStorage storage;

    ivec3 lastccp;              // in chunk coords
    ivec3 base;                 // in chunk coords
    ivec3 worldMin, worldMax;   // in world coords
    ulong totalGPUWrites;
    ulong totalCameraMoveUpdateTime;
    ulong totalChunkUpdateTime;
    ulong numCameraMoves;
    ulong numChunkUpdateBatches;

    ChunkInfo[ivec3] chunks;
    uint numOnGPU, numActive, numFlyweight;

    uint[VIEW_WINDOW_HMUL] chunkData;
    ChunkInfo[VIEW_WINDOW_HMUL] currentGrid;
    ChunkInfo[VIEW_WINDOW_HMUL] tempGrid;

    VBOMemoryManager vboVoxels;
    VBOMemoryManager vboChunks;

    static final class ChunkInfo {
        Chunk chunk;
        uint offset;
        uint size;
        bool onGPU;
        bool flyweight;
    }
public:
    ivec3[2] worldMinMax() { return [worldMin,worldMax]; }

    this(ChunkUpdateListener listener,
         World world,
         VBO voxelsVbo,
         VBO chunksVbo)
    {
        this.messages     = makeSPSCQueue!EventMsg(1024*1024);
        this.listener     = listener;
        this.world        = world;
        this.vboVoxels    = voxelsVbo.getMemoryManager();
        this.vboChunks    = chunksVbo.getMemoryManager();
        this.storage      = new ChunkStorage(world);

        getEvents().subscribe(
            "ChunkManager",
            EventID.CHUNK_UPDATED,
            messages
        );
        initialise();
    }
    void afterUpdate() {
        bool chunkDataChanged = false;

        // 1) check the camera position
        ivec3 ccp = (world.camera.position / CHUNK_SIZE)
                    .floor()
                    .to!int;
        if(ccp != lastccp) {
            chunkDataChanged = true;
            cameraMovedTo(ccp);
        }

        // 2) handle chunk update messages
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
            vboVoxels.numBytesUsed/MB,
            vboChunks.numBytesUsed/KB,
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
        log("ChunkManager: Initialising");

        lastccp = (world.camera.position / CHUNK_SIZE)
                  .floor()
                  .to!int;
        log("Camera pos = %s", world.camera.position);
        log("Camera chunk pos = %s", lastccp);

        base = lastccp - HALF_VIEW_WINDOW;
        log("Bounds(chunks) = %s %s", base, (base+(VIEW_WINDOW.to!int)));

        StopWatch watch; watch.start();
        uint index = 0;
        updateWorldBB(base*CHUNK_SIZE, (base+(VIEW_WINDOW.to!int))*CHUNK_SIZE);

        vboVoxels.bind();

        // point all DIAMETER^^3 chunks at offset 0
        for(auto z=0; z<VIEW_WINDOW.z; z++)
        for(auto y=0; y<VIEW_WINDOW.y; y++)
        for(auto x=0; x<VIEW_WINDOW.x; x++) {
            auto p  = base + ivec3(x,y,z);
            auto ci = activateChunk(p);

            ci.onGPU = true;
            numOnGPU++;

            ci.offset = cast(uint)vboVoxels.write(ci.chunk.voxels, 4);
            ci.size   = cast(uint)ci.chunk.voxels.length;
            totalGPUWrites += ci.size;
            currentGrid[index] = ci;

            index++;
        }
        writeChunkData();

        watch.stop();
        log("initialise took %s millis", watch.peek().total!"nsecs"/1000000.0);
    }
    /**
     *  The camera has moved to a different chunk. Update
     *  the visible window of voxelOffsets. Handle chunks
     *  entering and leaving the window.
     *
     *  Possible future optimisation:
     *      Increase the window dimension by 1 and update
     *      this in a background thread so that we have
     *      the chunks ready for when the camera actually
     *      reaches that position.
     */
    void cameraMovedTo(ivec3 ccp) {
        log("ChunkManager: camera moved to %s", ccp);
        StopWatch watch; watch.start();

        numCameraMoves++;
        ivec3 soffset = lastccp-ccp;
        lastccp = ccp;
        uvec3 uoffset = soffset.to!uint;
        int sadd      = (soffset*VIEW_WINDOW_MUL).hadd;

        int index = 0;
        tempGrid[] = currentGrid[];

        ivec3 oldBase = base;
        base = ccp - HALF_VIEW_WINDOW;
        updateWorldBB(base*CHUNK_SIZE, (base+VIEW_WINDOW.to!int)*CHUNK_SIZE);

        vboVoxels.bind();

        for(uint z=0; z<VIEW_WINDOW.z; z++)
        for(uint y=0; y<VIEW_WINDOW.y; y++)
        for(uint x=0; x<VIEW_WINDOW.x; x++) {
            uvec3 from  = uvec3(x,y,z) - uoffset;
            uvec3 to    = uvec3(x,y,z) + uoffset;
            //log("here=%s from=%s to=%s", here, from, to); flushLog();

            if(to.anyGTE(VIEW_WINDOW)) {
                // This chunk is moving out of bounds
                ivec3 pos = oldBase+ivec3(x,y,z);
                //log("going oob: %s %s", ivec3(x,y,z),pos);

                auto ci = getChunkInfo(pos);
                ci.onGPU = false;
                numOnGPU--;
                vboVoxels.free(ci.offset, ci.size);
            }

            if(from.anyGTE(VIEW_WINDOW)) {
                // This offset needs a new chunk
                ivec3 pos = base+ivec3(x,y,z);
                //log("coming in: %s %s", ivec3(x,y,z),pos);
                auto ci = activateChunk(pos);
                ci.onGPU = true;
                numOnGPU++;

                ci.offset = cast(uint)vboVoxels.write(ci.chunk.voxels, 4);
                auto length = cast(uint)ci.chunk.voxels.length;
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

        log("cameraMovedTo took %s millis", watch.peek().total!"nsecs"/1000000.0);
    }
    bool chunksUpdated(Chunk[] chunks) {
        StopWatch w; w.start();
        bool chunkDataChanged = false;

        vboVoxels.bind();

        foreach(c; chunks) {
            ChunkInfo ci = getChunkInfo(c);
            if(!ci) continue;

            if(ci.onGPU) {

//                log("update offset %s size %s to %s (voxelsOffset=%s)",
//                    ci.offset, ci.size, c.voxels.length, i);

                vboVoxels.free(ci.offset, ci.size);

                ci.offset = cast(uint)vboVoxels.write(c.voxels, 4);
                ci.size   = cast(uint)c.voxels.length;
                totalGPUWrites += ci.size;

                chunkDataChanged = true;
            }
        }

        w.stop();
        totalChunkUpdateTime += w.peek().total!"nsecs";
        numChunkUpdateBatches++;
        return chunkDataChanged;
    }
    void updateWorldBB(ivec3 min, ivec3 max) {
        worldMin = min;
        worldMax = max;
        listener.setBounds(VIEW_WINDOW, min, max);
    }
    void writeChunkData() {
        vboChunks.bind();
        ulong numBytes = chunkData.length*uint.sizeof;
        // free the existing region if it exists
        if(vboChunks.numBytesUsed>0) {
            vboChunks.free(0, numBytes);
        }
        // update chunkData
        uint* dest = chunkData.ptr;
        foreach(ci; currentGrid) {
            expect(ci.offset%4==0);
            *dest++ = ci.offset;
        }
        // write chunkData to VBO
        totalGPUWrites += numBytes;
        expect(0==vboChunks.write(chunkData, 4));
    }
//    uint getGridIndex(Chunk c) {
//        ivec3 p = c.pos-base;
//        //if(p.anyLT(0) || p.anyGTE(DIAMETER)) return -1;
//        //return p.x + p.y*DIAMETER + p.z*DIAMETER2;
//        return (p*VIEW_WINDOW_MUL).hadd;
//    }
    ChunkInfo getChunkInfo(Chunk c) {
        return getChunkInfo(c.pos);
    }
    ChunkInfo getChunkInfo(ivec3 p) {
        ChunkInfo* ptr = p in chunks;
        return ptr ? *ptr : null;
    }
    ChunkInfo activateChunk(ivec3 p) {
        auto ptr = (p in chunks);
        ChunkInfo ci;
        if(ptr) {
            ci = *ptr;
        } else {
            ci = new ChunkInfo;
            ci.chunk = storage.get(p);
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
//    void deactivateChunk(ivec3 p) {
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

