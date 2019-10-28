module blockie.model.Offset;

import blockie.all;

align(1):

struct Offset3 { static assert(Offset3.sizeof==3); align(1):
    ubyte[3] v;

    uint get() const {
        return (v[2]<<16) | (v[1]<<8) | v[0];
    }
    void set(uint o) {
        assert(o <= 0xff_ffff);
        v[0] = cast(ubyte)(o&0xff);
        v[1] = cast(ubyte)((o>>8)&0xff);
        v[2] = cast(ubyte)((o>>16)&0xff);
    }
    string toString() const { return "%s".format(get()*4); }
}

struct Offset4 { static assert(Offset4.sizeof==4); align(1):
    uint v;

    uint get() const { return v; }
    void set(uint o) { v = o; }

    string toString() const { return "%s".format(get()); }
}