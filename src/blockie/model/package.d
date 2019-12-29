module blockie.model;

import blockie.all;

public:

import blockie.model.Chunk;
import blockie.model.ChunkEditView;
import blockie.model.ChunkManager;
import blockie.model.ChunkSerialiser;
import blockie.model.ChunkStorage;
import blockie.model.Distance;
import blockie.model.DistanceField;
import blockie.model.DistanceFieldsBiDirCell;
import blockie.model.DistanceFieldsBiDirChunk;
import blockie.model.DistanceFieldsUniDirCell;
import blockie.model.event;
import blockie.model.Offset;
import blockie.model.Optimiser;
import blockie.model.voxel;
import blockie.model.world;
import blockie.model.WorldEditor;

interface Model {
    string          name();
    Chunk           makeChunk(chunkcoords coords);
    ChunkEditView   makeEditView();
    ChunkSerialiser makeChunkSerialiser(World w);
    int             numRootBits();
}

