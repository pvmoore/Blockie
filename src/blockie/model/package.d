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
import blockie.model.CellDistanceFields2;
import blockie.model.CellDistanceFieldsBiDirectional;
import blockie.model.ChunkDistanceFields;
import blockie.model.ChunkDistanceFields2;
import blockie.model.DistanceField;
import blockie.model.WorldEditor;

interface Model {
    string          name();
    Chunk           makeChunk(chunkcoords coords);
    ChunkSerialiser makeChunkSerialiser(World w);
    int numRootBits();
}

align(1) struct Distance3 { align(1):
    ubyte x,y,z;
    static assert(Distance3.sizeof==3);

    void set(ubyte x, ubyte y, ubyte z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    string toString() const { return "%s,%s,%s".format(x,y,z); }
}
