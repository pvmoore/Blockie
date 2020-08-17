module blockie.model.ChunkSerialiser;

import blockie.model;

abstract class ChunkSerialiser {
protected:
    const string AIR_CHUNKS_FILENAME = "air-chunks.dat";
    World world;
    Model model;
    Archive archive;

    static align(1) struct AirChunk { align(1):
        chunkcoords pos;
        Distance6 distance;

        static assert(AirChunk.sizeof==18);
    }

    abstract Chunk    toChunk(AirChunk ac);
    abstract AirChunk toAirChunk(Chunk chunk);
public:
    this(World w, Model model) {
        this.world = w;
        this.model = model;
        openArchive();
    }
    void destroy() {
        closeArchive();
    }

    ///
    /// Load a chunk and return the number of bytes read.
    /// This function sets the Chunk updated voxels ready for it
    /// to be activated.
    ///
    ulong load(Chunk c) {

        if(archive.contains(c.filename)) {

            ubyte[] voxels   = archive.getData!ubyte(c.filename);

            uint archVersion = archive.getComment(c.filename).to!uint;
            uint version_    = c.getVersion;

            uint ver = c.atomicUpdate(version_, voxels);
            if(ver != version_+1) {
                /// Our data is stale
                log("Loaded chunk data is stale version %s (Chunk version is %s)", version_, ver);
            }

            assert(c.getVersion()>0);

            return voxels.length;
        }

        /// This chunk is air.

        /// Set version to 1 if it is 0
        c.atomicUpdate(0, null);

        return 0;
    }
    ///
    /// Saves a Chunk and returns the number of bytes written.
    ///
    ulong save(Chunk c) {

        if(c.isAir()) {
            // todo - this needs to be versioned in some way

            archive.remove(c.filename);
            return 0;
        }

        archive.add(c.filename, c.voxels, c.version_.to!string);

        return c.voxels.length;
    }
    Chunk[] loadAirChunks() {

        if(archive.contains(AIR_CHUNKS_FILENAME)) {

            auto data = archive.getData!AirChunk(AIR_CHUNKS_FILENAME);

            auto chunks = new Chunk[data.length];
            foreach(i, airChunk; data) {
                chunks[i] = toChunk(airChunk);
                chunks[i].atomicUpdate(0, null);
            }
            return chunks;
        }
        return null;
    }
    void saveAirChunks(Chunk[] chunks) {
        auto airChunks = chunks.map!(it=>toAirChunk(it)).array;

        archive.add(AIR_CHUNKS_FILENAME,
            airChunks.ptr,
            airChunks.length*AirChunk.sizeof,
            airChunks.length.to!string);
    }
private:
    string getArchiveFilename() {
        return "data/%s/%s.chunks.zip".format(world.name, model.name());
    }
    void openArchive() {
        this.archive = new Archive(getArchiveFilename());
    }
    void closeArchive() {
        archive.close();
    }
}