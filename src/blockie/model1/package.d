module blockie.model1;

public:

import blockie.all;

import blockie.model1.M1Chunk;
import blockie.model1.M1ChunkEditView;
import blockie.model1.M1ChunkSerialiser;
import blockie.model1.octree;
import blockie.model1.optimise;

const M1_OCTREE_ROOT_BITS = 4;

final class Model1 : Model {
public:
    string          name() { return "M1"; }
    Chunk           makeChunk(chunkcoords coords) { return new M1Chunk(coords); }
    ChunkSerialiser makeChunkSerialiser(World w)  { return new M1ChunkSerialiser(w, this); }
    int             numRootBits() { return M1_OCTREE_ROOT_BITS; }
}