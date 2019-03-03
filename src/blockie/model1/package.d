module blockie.model1;

public:

import blockie.all;

import blockie.model1.M1Chunk;
import blockie.model1.M1ChunkEditView;
import blockie.model1.M1ChunkSerialiser;
import blockie.model1.M1Optimiser;
import blockie.model1.M1WorldEditor;


const M1_OCTREE_ROOT_BITS = 4;
const M1_CELLS_PER_CHUNK  = 16*16*16; // 4096

final class Model1 : Model {
public:
    string          name()                        { return "M1"; }
    Chunk           makeChunk(chunkcoords coords) { return new M1Chunk(coords); }
    ChunkEditView   makeEditView()                { return new M1ChunkEditView; }
    ChunkSerialiser makeChunkSerialiser(World w)  { return new M1ChunkSerialiser(w, this); }
    int             numRootBits()                 { return M1_OCTREE_ROOT_BITS; }
}