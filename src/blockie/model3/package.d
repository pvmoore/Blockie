module blockie.model3;

public:

import blockie.model;

import blockie.model3.M3Chunk;
import blockie.model3.M3ChunkEditView;
import blockie.model3.M3ChunkSerialiser;
import blockie.model3.M3DeOptimiser;
import blockie.model3.M3Optimiser;
import blockie.model3.M3WorldEditor;

///
/// Same as Model2 but using 5 bits for the root instead of 4
///

enum M3_OCTREE_ROOT_BITS = 5;
enum M3_ROOT_SIZE        = M3Root.sizeof.as!uint;
enum M3_CELLS_PER_CHUNK  = 32*32*32;   // 32768

final class Model3 : Model {
public:
    string          name()                        { return "M3"; }
    Chunk           makeChunk(chunkcoords coords) { return new M3Chunk(coords); }
    ChunkEditView   makeEditView()                { return new M3ChunkEditView; }
    ChunkSerialiser makeChunkSerialiser(World w)  { return new M3ChunkSerialiser(w, this); }
    int             numRootBits()                 { return M3_OCTREE_ROOT_BITS; }
}
