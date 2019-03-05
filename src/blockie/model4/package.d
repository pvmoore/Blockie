module blockie.model4;

public:

import blockie.all;

import blockie.model4.M4Chunk;
import blockie.model4.M4ChunkEditView;
import blockie.model4.M4ChunkSerialiser;
import blockie.model4.M4DeOptimiser;
import blockie.model4.M4Optimiser;
import blockie.model4.M4WorldEditor;

version = ROOT7;

version(ROOT6) {
    const M4_OCTREE_ROOT_BITS = 6;
    const M4_ROOT_SIZE        = M4Root.sizeof.as!uint;
    const M4_CELLS_PER_CHUNK  = 64*64*64;   // 262,144
    const M4_PIXELS_PER_CELL  = 4096;
    const M4_PIXELS_SIZE      = M4_PIXELS_PER_CELL / 8; // each pixel is a bit
}
version(ROOT7) {
    const M4_OCTREE_ROOT_BITS = 7;
    const M4_ROOT_SIZE        = M4Root.sizeof.as!uint;
    const M4_CELLS_PER_CHUNK  = 128*128*128;   // 2,097,152
    const M4_PIXELS_PER_CELL  = 512;
    const M4_PIXELS_SIZE      = M4_PIXELS_PER_CELL / 8; // each pixel is a bit
    //pragma(msg, "M4_ROOT_SIZE = %s".format(M4_ROOT_SIZE));
}

final class Model4 : Model {
    public:
    string          name()                        { return "M4"; }
    Chunk           makeChunk(chunkcoords coords) { return new M4Chunk(coords); }
    ChunkEditView   makeEditView()                { return new M4ChunkEditView; }
    ChunkSerialiser makeChunkSerialiser(World w)  { return new M4ChunkSerialiser(w, this); }
    int             numRootBits()                 { return M4_OCTREE_ROOT_BITS; }
}