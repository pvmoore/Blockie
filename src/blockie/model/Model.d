module blockie.model.Model;

import blockie.model;

interface Model {
    string          name();
    Chunk           makeChunk(chunkcoords coords);
    ChunkEditView   makeEditView();
    ChunkSerialiser makeChunkSerialiser(World w);

    // This should probably not be here
    int             numRootBits();
}

Model createModel() {
    static if(MODEL==1) return new Model1;
    else static if(MODEL==2) return new Model2;
    else static if(MODEL==3) return new Model3;
    else static assert(false);
}
