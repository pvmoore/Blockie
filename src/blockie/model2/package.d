module blockie.model2;

public:

import blockie.all;

import blockie.model2.M2Chunk;
import blockie.model2.M2ChunkEditView;
import blockie.model2.M2ChunkSerialiser;
import blockie.model2.M2Optimiser;
import blockie.model2.M2WorldEditor;

final class Model2 : Model {
    public:
        Chunk           makeChunk(chunkcoords coords) { return new M2Chunk(coords); }
        ChunkSerialiser makeChunkSerialiser(World w)  { return new M2ChunkSerialiser(w); }
}