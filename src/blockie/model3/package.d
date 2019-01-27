module blockie.model3;

public:

import blockie.all;

import blockie.model3.M3Chunk;
import blockie.model3.M3ChunkEditView;
import blockie.model3.M3ChunkSerialiser;
import blockie.model3.M3Optimiser;
import blockie.model3.M3WorldEditor;

const M3_OCTREE_ROOT_BITS = 5;

final class Model3 : Model {
public:
    Chunk           makeChunk(chunkcoords coords) { return new M3Chunk(coords); }
    ChunkSerialiser makeChunkSerialiser(World w)  { return new M3ChunkSerialiser(w); }
    int             numRootBits() { return M3_OCTREE_ROOT_BITS; }
}
