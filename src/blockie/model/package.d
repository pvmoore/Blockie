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

interface Model {
    string          name();
    Chunk           makeChunk(chunkcoords coords);
    ChunkEditView   makeEditView();
    ChunkSerialiser makeChunkSerialiser(World w);
    int             numRootBits();
}

Model createModel() {
    static if(MODEL==1) return new Model1;
    else static if(MODEL==2) return new Model2;
    else static if(MODEL==3) return new Model3;
    else static assert(false);
}
