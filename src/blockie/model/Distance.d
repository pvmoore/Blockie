module blockie.model.Distance;

import blockie.model;

align(1):

/**
 * 8 bits per axis.
 */
struct Distance3 { static assert(Distance3.sizeof==3); align(1):
    ubyte x,y,z;

    void set(Distance3 d) {
        x = d.x;
        y = d.y;
        z = d.z;
    }
    void set(uint x, uint y, uint z) {
        this.x = x.as!ubyte;
        this.y = y.as!ubyte;
        this.z = z.as!ubyte;
    }

    string toString() const { return "%s,%s,%s".format(x,y,z); }

    bool opEquals(inout Distance3 o) const {
        return x==o.x && y==o.y && z==o.z;
    }
    size_t toHash() const nothrow @trusted {
        ulong a = 5381;
        a  = (a << 7)  + x;
        a ^= (a << 13) + y;
        a  = (a << 19) + z;
        return a;
    }
}
/**
 *  10 bits per axis. 2 bits unused.
 */
struct Distance4 { static assert(Distance4.sizeof==4); align(1):
    uint value;
nothrow {
    uint x() const { return value & 1023; }
    uint y() const { return (value>>10) & 1023; }
    uint z() const { return (value>>20) & 1023; }
}
    void set(Distance4 d) {
        this.value = d.value;
    }
    void set(uint x, uint y, uint z) {
        this.value = 0;
        this.value |= x;
        this.value |= (y << 10);
        this.value |= (z << 20);
    }

    string toString() const { return "%s,%s,%s".format(x(), y(), z()); }

    bool opEquals(inout Distance4 o) const {
        return this.value==o.value;
    }
    size_t toHash() const nothrow @trusted {
        ulong a = 5381;
        a  = (a << 7)  + x();
        a ^= (a << 13) + y();
        a  = (a << 19) + z();
        return a;
    }
}
/**
 * 16 bits per axis.
 */
struct Distance6 { static assert(Distance6.sizeof==6); align(1):
    ubyte xdown, xup,
          ydown, yup,
          zdown, zup;

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
        a  = (a << 7)  + xdown;
        a ^= (a << 13) + ydown;
        a  = (a << 19) + zdown;

        a  = (a << 23) + xup;
        a ^= (a << 29) + yup;
        a  = (a << 31) + zup;
        return a;
    }
    string toString() const { return "%s-%s, %s-%s, %s-%s".format(xdown,xup,ydown,yup,zdown,zup); }
}