module blockie.model4.M4ChunkSerialiser;

import blockie.all;

final class M4ChunkSerialiser : ChunkSerialiser {
protected:
    override Chunk toChunk(AirChunk ac) {
        auto chunk = new M4Chunk(ac.pos);
        chunk.root.distance.x = ac.distX;
        chunk.root.distance.y = ac.distY;
        chunk.root.distance.z = ac.distZ;
        return chunk;
    }
    override AirChunk toAirChunk(Chunk chunk) {
        auto root = (cast(M4Chunk)chunk).root();
        return AirChunk(
            chunk.pos,
            root.distance.x,
            root.distance.y,
            root.distance.z,
        );
    }
public:
    this(World w, Model model) {
        super(w, model);
    }
}
