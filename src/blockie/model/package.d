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
import blockie.model.CellDistanceFieldsBiDirectional;
import blockie.model.ChunkDistanceFields;
import blockie.model.DistanceField;
import blockie.model.WorldEditor;

interface Model {
    string          name();
    Chunk           makeChunk(chunkcoords coords);
    ChunkEditView   makeEditView();
    ChunkSerialiser makeChunkSerialiser(World w);
    int             numRootBits();
}

//===========================================================================
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

align(1) struct Distance6 { align(1):
    ubyte x1,x2, y1,y2, z1, z2;
    static assert(Distance6.sizeof==6);

    void set(ubyte x1, ubyte x2, ubyte y1, ubyte y2, ubyte z1, ubyte z2) {
        this.x1 = x1;
        this.x2 = x2;
        this.y1 = y1;
        this.y2 = y2;
        this.z1 = z1;
        this.z2 = z2;
    }
    void set(DFieldsBi f) {
        x1 = f.x.up.as!ubyte;
        x2 = f.x.down.as!ubyte;
        y1 = f.y.up.as!ubyte;
        y2 = f.y.down.as!ubyte;
        z1 = f.z.up.as!ubyte;
        z2 = f.z.down.as!ubyte;
    }
    string toString() const { return "%s-%s, %s-%s, %s-%s".format(x1,x2,y1,y2,z1,z2); }
}
//===========================================================================
align(1) struct Offset3 { align(1):
    ubyte[3] v;
    static assert(Offset3.sizeof==3);

    uint get() const { return (v[2]<<16) | (v[1]<<8) | v[0]; }
    void set(uint o) {
        assert(o <= 0xffffff);
        v[0] = cast(ubyte)(o&0xff);
        v[1] = cast(ubyte)((o>>8)&0xff);
        v[2] = cast(ubyte)((o>>16)&0xff);
    }
    string toString() const { return "%s".format(get()*4); }
}
//===========================================================================
