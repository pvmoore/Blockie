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
import blockie.model.DistanceField;
import blockie.model.DistanceFieldsBiDirCell;
import blockie.model.DistanceFieldsBiDirChunk;
import blockie.model.DistanceFieldsUniDirCell;
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

    void set(Distance3 d) {
        x = d.x;
        y = d.y;
        z = d.z;
    }
    void set(ubyte x, ubyte y, ubyte z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    string toString() const { return "%s,%s,%s".format(x,y,z); }

    bool opEquals(inout Distance3 o) const {
        return x==o.x && y==o.y && z==o.z;
    }
    size_t toHash() const nothrow @trusted {
        ulong a = 5381;
        a  = ((a << 7) )  + x;
        a ^= ((a << 13) ) + y;
        a  = ((a << 19) ) + z;
        return a;
    }
}

align(1) struct Distance6 { align(1):
    ubyte xdown, xup,
          ydown, yup,
          zdown, zup;
    static assert(Distance6.sizeof==6);

    void clear() {
        xdown = xup = ydown = yup = zdown = zup = 0;
    }
    void set(Distance6 d) {
        xdown = d.xdown; xup = d.xup;
        ydown = d.ydown; yup = d.yup;
        zdown = d.zdown; zup = d.zup;
    }
    void set(DFieldsBi f) {
        xdown = f.x.down.as!ubyte;
        xup   = f.x.up.as!ubyte;

        ydown = f.y.down.as!ubyte;
        yup   = f.y.up.as!ubyte;

        zdown = f.z.down.as!ubyte;
        zup   = f.z.up.as!ubyte;
    }
    ubyte[] toBytes() {
        return [xdown, xup, ydown, yup, zdown, zup];
    }
    bool opEquals(inout Distance6 o) const {
        return xdown==o.xdown && xup==o.xup &&
               ydown==o.ydown && yup==o.yup &&
               zdown==o.zdown && zup==o.zup;
    }
    size_t toHash() const nothrow @trusted {
        ulong a = 5381;
        a  = ((a << 7) )  + xdown;
        a ^= ((a << 13) ) + ydown;
        a  = ((a << 19) ) + zdown;

        a  = ((a << 23) ) + xup;
        a ^= ((a << 29) ) + yup;
        a  = ((a << 31) ) + zup;
        return a;
    }
    string toString() const { return "%s-%s, %s-%s, %s-%s".format(xdown,xup,ydown,yup,zdown,zup); }
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
align(1) struct Offset4 { align(1):
    uint v;
    static assert(Offset4.sizeof==4);

    uint get() const { return v; }
    void set(uint o) { v = o; }

    string toString() const { return "%s".format(get()); }
}
//===========================================================================
