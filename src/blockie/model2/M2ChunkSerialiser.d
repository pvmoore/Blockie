module blockie.model2.M2ChunkSerialiser;

import blockie.model;

final class M2ChunkSerialiser : ChunkSerialiser {
protected:
    override Chunk toChunk(AirChunk ac) {
        auto chunk = new M2Chunk(ac.pos);
        chunk.root.distance.set(ac.distance);
        return chunk;
    }
    override AirChunk toAirChunk(Chunk chunk) {
        auto root = (cast(M2Chunk)chunk).root();
        return AirChunk(
            chunk.pos,
            root.distance
        );
    }
public:
    this(World w, Model model) {
        super(w, model);
    }
}
