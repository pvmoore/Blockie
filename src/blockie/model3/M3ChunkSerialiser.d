module blockie.model3.M3ChunkSerialiser;

import blockie.all;

final class M3ChunkSerialiser : ChunkSerialiser {
protected:
    override Chunk toChunk(AirChunk ac) {
        auto chunk = new M3Chunk(ac.pos);
        chunk.root.distance.set(ac.distance);
        return chunk;
    }
    override AirChunk toAirChunk(Chunk chunk) {
        auto root = (cast(M3Chunk)chunk).root();
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
