module blockie.model.model1a;

public:

import blockie.all;
import blockie.model.model1a.M1aChunk;
import blockie.model.model1a.M1aChunkEditView;
import blockie.model.model1a.M1aChunkOptView;
import blockie.model.model1a.M1aChunkSerialiser;
import blockie.model.model1a.M1aDeoptimiser;
import blockie.model.model1a.M1aOptimiser;
import blockie.model.model1a.M1aWorldEditor;

enum M1a_ROOT_BITS       = 4;
enum M1a_CELLS_PER_CHUNK = 16*16*16; // 4096

//enum M1a_ROOT_BITS       = 5;
//enum M1a_CELLS_PER_CHUNK = 32*32*32; // 32768

final class Model1a : Model {
public:
    string          name()                        { return "M1a"; }
    Chunk           makeChunk(chunkcoords coords) { return new M1aChunk(coords); }
    ChunkEditView   makeEditView()                { return new M1aChunkEditView; }
    ChunkSerialiser makeChunkSerialiser(World w)  { return new M1aChunkSerialiser(w, this); }
    int             numRootBits()                 { return M1a_ROOT_BITS; }
}