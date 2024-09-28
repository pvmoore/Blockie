module blockie.model2;

public:

import blockie.model;

import blockie.model2.M2Chunk;
import blockie.model2.M2ChunkEditView;
import blockie.model2.M2ChunkSerialiser;
import blockie.model2.M2DeOptimiser;
import blockie.model2.M2Optimiser;
import blockie.model2.M2WorldEditor;

/**
 *
 *
 *
 */

const M2_OCTREE_ROOT_BITS = 4;
const M2_ROOT_SIZE        = M2Root.sizeof.as!uint;
const M2_CELLS_PER_CHUNK  = 16*16*16; // 4096

final class Model2 : Model {
public:
    string          name()                        { return "M2"; }
    Chunk           makeChunk(chunkcoords coords) { return new M2Chunk(coords); }
    ChunkEditView   makeEditView()                { return new M2ChunkEditView; }
    ChunkSerialiser makeChunkSerialiser(World w)  { return new M2ChunkSerialiser(w, this); }
    int             numRootBits()                 { return M2_OCTREE_ROOT_BITS; }
}
