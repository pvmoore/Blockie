module blockie.model1.M1ChunkSerialiser;

import blockie.model;

final class M1ChunkSerialiser : ChunkSerialiser {
protected:
    override Chunk toChunk(AirChunk ac) {
        auto chunk = new M1Chunk(ac.pos);
        chunk.root().flags.distance.set(ac.distance);
        return chunk;
    }
    override AirChunk toAirChunk(Chunk chunk) {
        auto root = (cast(M1Chunk)chunk).root();
        return AirChunk(
            chunk.pos,
            root.flags.distance
        );
    }
public:
    this(World w, Model model) {
        super(w, model);
    }
}
