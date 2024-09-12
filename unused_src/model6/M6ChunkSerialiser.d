module blockie.model.model6.M6ChunkSerialiser;

import blockie.model;

final class M6ChunkSerialiser : ChunkSerialiser {
protected:
    override Chunk toChunk(AirChunk ac) {
        auto chunk = new M6Chunk(ac.pos);
        chunk.airRoot().distance.set(ac.distance);
        return chunk;
    }
    override AirChunk toAirChunk(Chunk chunk) {
        auto root = (cast(M6Chunk)chunk).airRoot();
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