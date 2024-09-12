module blockie.model4.M4ChunkSerialiser;

import blockie.model;

final class M4ChunkSerialiser : ChunkSerialiser {
protected:
    override Chunk toChunk(AirChunk ac) {
        auto chunk = new M4Chunk(ac.pos);
        chunk.root.distance.set(ac.distance);
        return chunk;
    }
    override AirChunk toAirChunk(Chunk chunk) {
        auto root = (cast(M4Chunk)chunk).root();
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
