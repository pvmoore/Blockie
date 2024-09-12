module blockie.model5;

public:

import blockie.model;
import blockie.model5.M5Chunk;
import blockie.model5.M5ChunkEditView;
import blockie.model5.M5ChunkSerialiser;
import blockie.model5.M5DeOptimiser;
import blockie.model5.M5Optimiser;
import blockie.model5.M5WorldEditor;

const M5_OCTREE_ROOT_BITS = 4;
const M5_ROOT_SIZE        = M5Root.sizeof.as!uint;
const M5_CELLS_PER_CHUNK  = 16*16*16;   // 4096

final class Model5 : Model {
public:
    string          name()                        { return "M5"; }
    Chunk           makeChunk(chunkcoords coords) { return new M5Chunk(coords); }
    ChunkEditView   makeEditView()                { return new M5ChunkEditView; }
    ChunkSerialiser makeChunkSerialiser(World w)  { return new M5ChunkSerialiser(w, this); }
    int             numRootBits()                 { return M5_OCTREE_ROOT_BITS; }
}