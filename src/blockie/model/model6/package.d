module blockie.model.model6;

public:

import blockie.all;

import blockie.model.model6.M6Chunk;
import blockie.model.model6.M6ChunkEditView;
import blockie.model.model6.M6ChunkSerialiser;
import blockie.model.model6.M6DeOptimiser;
import blockie.model.model6.M6Optimiser;
import blockie.model.model6.M6WorldEditor;

enum M6_OCTREE_ROOT_BITS = 5;
enum M6_ROOT_SIZE        = M6Root.sizeof.as!uint;
enum M6_CELLS_PER_CHUNK  = 32*32*32;   // 32768
enum M6_VOXELS_PER_CELL  = 32*32*32;   // 32768

final class Model6 : Model {
public:
    string          name()                        { return "M6"; }
    Chunk           makeChunk(chunkcoords coords) { return new M6Chunk(coords); }
    ChunkEditView   makeEditView()                { return new M6ChunkEditView; }
    ChunkSerialiser makeChunkSerialiser(World w)  { return new M6ChunkSerialiser(w, this); }
    int             numRootBits()                 { return M6_OCTREE_ROOT_BITS; }
}

void chat(A...)(lazy string fmt, lazy A args) {
    static if(true) {
        writefln(format(fmt, args));
        flushConsole();
    }
}