module blockie.model5.M5ChunkSerialiser;

import blockie.all;

final class M5ChunkSerialiser : ChunkSerialiser {
protected:
    override Chunk toChunk(AirChunk ac) {
        auto chunk = new M5Chunk(ac.pos);
        chunk.root.distance.set(ac.distance);
        return chunk;
    }
    override AirChunk toAirChunk(Chunk chunk) {
        auto root = (cast(M5Chunk)chunk).root();
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