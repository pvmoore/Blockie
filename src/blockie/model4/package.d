module blockie.model4;

public:

import blockie.all;

import blockie.model4.M4Chunk;
import blockie.model4.M4ChunkEditView;
import blockie.model4.M4ChunkSerialiser;
import blockie.model4.M4DeOptimiser;
import blockie.model4.M4Optimiser;
import blockie.model4.M4WorldEditor;

const M4_OCTREE_ROOT_BITS = 6;
const M4_ROOT_SIZE        = M4Root.sizeof.as!uint;
const M4_CELLS_PER_CHUNK  = 64*64*64;
const M4_PIXELS_PER_CELL  = 4096;
const M4_PIXELS_SIZE      = M4_PIXELS_PER_CELL / 8; // each pixel is a bit

final class Model4 : Model {
    public:
    string          name()                        { return "M4"; }
    Chunk           makeChunk(chunkcoords coords) { return new M4Chunk(coords); }
    ChunkEditView   makeEditView()                { return new M4ChunkEditView; }
    ChunkSerialiser makeChunkSerialiser(World w)  { return new M4ChunkSerialiser(w, this); }
    int             numRootBits()                 { return M4_OCTREE_ROOT_BITS; }
}