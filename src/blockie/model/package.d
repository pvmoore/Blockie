module blockie.model;

public:

import maths;
import maths.camera;
import maths.noise;

import blockie.globals;

import blockie.model.Chunk;
import blockie.model.ChunkEditView;
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

import blockie.model1;
import blockie.model2;
import blockie.model3;
import blockie.model4;
import blockie.model5;
import blockie.model.model6;
import blockie.model.model1a;

interface Model {
    string          name();
    Chunk           makeChunk(chunkcoords coords);
    ChunkEditView   makeEditView();
    ChunkSerialiser makeChunkSerialiser(World w);
    int             numRootBits();
}

