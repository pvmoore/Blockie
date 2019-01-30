module blockie.model;

import blockie.all;

public:

import blockie.model.event;
import blockie.model.getoctet;
import blockie.model.voxel;
import blockie.model.world;
import blockie.model.Chunk;
import blockie.model.ChunkEditView;
import blockie.model.ChunkManager;
import blockie.model.ChunkSerialiser;
import blockie.model.ChunkStorage;
import blockie.model.CellDistanceFields;
import blockie.model.CellDistanceFieldsDirectional;
import blockie.model.ChunkDistanceFields;
import blockie.model.WorldEditor;

interface Model {
    string          name();
    Chunk           makeChunk(chunkcoords coords);
    ChunkSerialiser makeChunkSerialiser(World w);
    int numRootBits();
}
