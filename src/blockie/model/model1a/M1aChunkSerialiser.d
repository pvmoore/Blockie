module blockie.model.model1a.M1aChunkSerialiser;

import blockie.model;
import blockie.model.model1a;

final class M1aChunkSerialiser : ChunkSerialiser {
protected:
    override Chunk toChunk(AirChunk ac) {
        auto chunk = new M1aChunk(ac.pos);
        chunk.optRoot.flags.distance.set(ac.distance);
        return chunk;
    }
    override AirChunk toAirChunk(Chunk chunk) {
        auto root = (cast(M1aChunk)chunk).optRoot();
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