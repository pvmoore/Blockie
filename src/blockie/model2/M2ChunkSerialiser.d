module blockie.model2.M2ChunkSerialiser;

import blockie.all;

final class M2ChunkSerialiser : ChunkSerialiser {
    protected:
    override string getChunkFilename(Chunk chunk) {
        return "data/" ~ world.name ~ "/M2." ~ chunk.filename;
    }
    override string getAirChunksFilename() {
        return "data/" ~ world.name ~ "/M2.air-chunks.dat";
    }
    override Chunk toChunk(AirChunk ac) {
        auto chunk = new M2Chunk(ac.pos);
        chunk.root.distance.x = ac.distX;
        chunk.root.distance.y = ac.distY;
        chunk.root.distance.z = ac.distZ;
        return chunk;
    }
    override AirChunk toAirChunk(Chunk chunk) {
        auto root = (cast(M2Chunk)chunk).root();
        return AirChunk(
            chunk.pos,
            root.distance.x,
            root.distance.y,
            root.distance.z,
        );
    }
public:
    this(World w) {
        super(w);
    }
}
