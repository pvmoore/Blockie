module blockie.model1.M1ChunkSerialiser;

import blockie.all;

final class M1ChunkSerialiser : ChunkSerialiser {
protected:
    override Chunk toChunk(AirChunk ac) {
        auto chunk = new M1Chunk(ac.pos);
        chunk.optimisedRoot.flags.distX = ac.distX;
        chunk.optimisedRoot.flags.distY = ac.distY;
        chunk.optimisedRoot.flags.distZ = ac.distZ;
        return chunk;
    }
    override AirChunk toAirChunk(Chunk chunk) {
        auto root = (cast(M1Chunk)chunk).optimisedRoot();
        return AirChunk(
            chunk.pos,
            root.flags.distX,
            root.flags.distY,
            root.flags.distZ
        );
    }
public:
    this(World w, Model model) {
        super(w, model);
    }
}
