module blockie.model1;

public:

import blockie.all;

import blockie.model1.M1Chunk;
import blockie.model1.M1ChunkEditView;
import blockie.model1.M1ChunkSerialiser;

import blockie.model1.octree;
import blockie.model1.optimise;

final class Model1 : Model {
    public:
        Chunk           makeChunk(chunkcoords coords) { return new M1Chunk(coords); }
        ChunkSerialiser makeChunkSerialiser(World w)  { return new M1ChunkSerialiser(w); }
}