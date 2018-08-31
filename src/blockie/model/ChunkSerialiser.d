module blockie.model.ChunkSerialiser;

import blockie.all;

abstract class ChunkSerialiser {
protected:
    World world;

    static struct ChunkHeader {
        uint reserved;

        static assert(ChunkHeader.sizeof==4);
    }

    static align(1) struct AirChunk { align(1):
        chunkcoords pos;
        ubyte distX;
        ubyte distY;
        ubyte distZ;

        static assert(AirChunk.sizeof==15);
    }

    abstract string getChunkFilename(Chunk chunk);
    abstract string getAirChunksFilename();
    abstract Chunk toChunk(AirChunk ac);
    abstract AirChunk toAirChunk(Chunk chunk);
public:
    this(World w) {
        this.world = w;
    }

    ///
    /// Load a chunk and return the number of bytes read.
    /// This function sets the Chunk updated voxels ready for it
    /// to be activated.
    ///
    ulong load(Chunk c) {
        string filename = getChunkFilename(c);

        if(false==FQN!"std.file".exists(filename)) {
            /// This chunk is air.

            /// Set version to 1 if it is 0
            c.atomicUpdate(0, null);
            return 0;
        }
        scope f       = File(filename, "rb");
        auto fileSize = f.size();

        ChunkHeader[1] header;
        f.rawRead(header);

        ubyte[] voxels = new ubyte[fileSize - ChunkHeader.sizeof];
        uint version_  = c.getVersion;
        f.rawRead(voxels);

        uint ver = c.atomicUpdate(version_, voxels);
        if(ver != version_+1) {
            /// Our data is stale
            log("Loaded chunk data is stale version %s (Chunk version is %s)", version_, ver);
        }
        assert(c.getVersion()>0);

        return fileSize;
    }
    ///
    /// Saves a Chunk and returns the number of bytes written.
    ///
    ulong save(Chunk c) {
        string filename = getChunkFilename(c);

        if(c.isAir()) {
            // todo - this needs to be versioned in some way
            if(exists(filename)) {
                import std.file : remove;
                remove(filename);
            }
            return 0;
        }

        scope f = File(filename, "wb");

        ChunkHeader header;
        header.reserved = c.version_;

        f.rawWrite([header]);
        f.rawWrite(c.voxels);

        return ChunkHeader.sizeof + c.voxels.length;
    }
    Chunk[] loadAirChunks() {
        string filename = getAirChunksFilename();
        if(!exists(filename)) return null;
        scope f = File(filename, "rb");
        if(f.size==0) return null;

        auto data = new AirChunk[f.size/AirChunk.sizeof];
        f.rawRead(data);

        auto chunks = new Chunk[data.length];
        foreach(i, airChunk; data) {
            chunks[i] = toChunk(airChunk);
            chunks[i].atomicUpdate(0, null);
        }
        return chunks;
    }
    void saveAirChunks(Chunk[] chunks) {
        auto airChunks = chunks.map!(it=>toAirChunk(it)).array;
        scope f = File(getAirChunksFilename(), "wb");
        f.rawWrite(airChunks);
    }
}