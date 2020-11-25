module blockie.model.model6.M6Chunk;

import blockie.model;

final class M6Chunk : Chunk {
public:
    this(chunkcoords coords) {
        super(coords);

        /// Set to air
        voxels.length = 8;
        auto r = airRoot();
        r.flag = M6Flag.AIR;
        r.distance.clear();
    }

    override bool isAir() {
        return airRoot().flag==M6Flag.AIR;
    }

    M6AirRoot* airRoot() { return cast(M6AirRoot*)voxels.ptr; }
}

enum M6Flag     : ubyte { AIR=0, MIXED }
enum M6CellFlag : ubyte { AIR=0, MIXED }

align(1):

struct M6AirRoot { align(1): static assert(M6AirRoot.sizeof == 8);
    M6Flag flag;
    ubyte _reserved;
    Distance6 distance;
}

struct M6Root { align(1):
    static assert(M6Root.sizeof==8 + M6_VOXELS_PER_CELL + M6_VOXELS_PER_CELL*M6Cell.sizeof);

    //--------------------------------------- Always present
    M6Flag flag;
    ubyte _reserved;
    //--------------------------------------- Present if flag == AIR
    Distance6 distance;
    //--------------------------------------- Present if flag == MIXED
    M6CellFlag[M6_VOXELS_PER_CELL] cellFlags;
    M6Cell[M6_CELLS_PER_CHUNK] cells;
    //-----------------------------------------------------------------------------------

    bool isAir() const   { return flag==M6Flag.AIR; }
    bool isMixed() const { return flag==M6Flag.MIXED; }

    bool isAirCell(uint index) {
        assert(index<M6_CELLS_PER_CHUNK);
        return cellFlags[index] == M6CellFlag.AIR;
    }

    // M6Cell* getCell(ubyte* ptr, uint oct) {
    //     assert(oct<M6_CELLS_PER_CHUNK);
    //     return cast(M6Cell*)(ptr+8+(oct*M6Cell.sizeof));
    // }
    void recalculateFlags() {
        if(allCellsAreAir()) {
            flag = M6Flag.AIR;
        } else {
            flag = M6Flag.MIXED;

            foreach(i, ref c; cells) {
                if(!isAirCell(i.as!int)) {
                    c.mixed.editFinished();
                }
            }
        }
    }
    string toString() const {
        if(isAir) return "AIR(%s)".format(distance);
        return "MIXED";
    }
private:
    bool allCellsAreAir() {
        foreach(c; cellFlags) {
            if(c != M6CellFlag.AIR) return false;
        }
        return true;
    }
}

union M6Cell {
    Distance3 distance;
    M6MixedCell mixed;
}

/**
 *
 * Min size = 128+32+4    = 164  bytes
 * Max size = 128+32+4096 = 4256 bytes
 * eg.
 * index:  |    0 |    1 |    2 |    3 |
 * bits:   | 0111 | 1001 | 1110 | 0010 |
 * counts: |    0 |    3 |    5 |    8 |  (bit count at index-1)

xyBits (1 bit per Z row):  Each bit represents 32 bits on the z axis

     0 1 2 .. 31
   -----------x
 0 | 0 0 0 ..       xyBits[0]
 1 | 0 0 0 ..       xyBits[1]
 2 | 0 0 0 ..       xyBits[2]
 ..| . . . ..       ..
 31|
   y
 */
struct M6MixedCell { align(1):
    uint[32] xyBits;    // 1024 bits, each one represents a Z row or 32 voxels (32768 voxels in total)
    uint[32] xyCounts;
    uint[] zValues;     // 0..1024 uints
    uint[ushort] zHash;

    uint getXRankBits() {
        uint rank;
        foreach(i; 0..32) {
            rank |= xyBits[i];
            //if(xyBits[i] != 0) rank |= (1<<i);
        }
        return rank;
    }
    uint getYRankBits() {
        uint rank;
        foreach(y; 0..32) {
            if(xyBits[y] != 0) {
                rank |= (1<<y);
            }
            // uint v = 0;
            // foreach(x; 0..32) {
            //     if(xyBits[y] & (1<<x)) { v = 1; break; }
            // }
            // rank |= (v<<x);
        }
        return rank;
    }

    /** Convert zHash values to zValues array and set xyCounts*/
    void editFinished() {
        uint count = 0;
        foreach(y; 0..32) {

            xyCounts[y] = count;

            count += popcnt(xyBits[y]);

            foreach(x; 0..32) {
                if(xyBits[y] & (1<<x)) {
                    ushort key = ((y<<5) + x).as!ushort;
                    uint zRow = zHash[key];
                    zValues ~= zRow;
                }
            }
        }
        zHash = null;
    }

    /** Solid if all bits are set */
    bool isSolid() {
        if(zHash.length < 1024) return false;
        foreach(z; zHash.values) {
            if(z != 0xffff_ffff) return false;
        }
        return true;
    }

    // bool isSet(uint index) {
    //     assert(index<M6_VOXELS_PER_CELL);

    //     const i = (index >>> 5) & 31;
    //     const r = ((index >>> 10) & 31) << 0;
    //     const b = 0 != (xyBits[i] & (1<<r));

    //     if(!b) return false;

    //     const j = xyCounts[i] + getImpliedIndex_32bit(xyBits[i], r);

    //     return 0 != (zValues[j] & (1<<(index&31)) );
    // }

    /**
     *  Set voxel at index (0..32767) (0 .. 2^^15-1)
     */
    void set(uint index, bool value) {
        assert(index<M6_VOXELS_PER_CELL);
        if(!value) { unset(index); return; }

        const x = index & 31;
        const y = (index >>> 5) & 31;
        const z = index >>> 10;

        ushort key = ((y<<5) + x).as!ushort;
        auto h = key in zHash;
        if(h) {
            (*h) |= (1<<z);
        } else {
            zHash[key] = 1<<z;
        }

        xyBits[y] |= (1<<x);
    }
    string toString() {
        string s;
        foreach(i; 0..32) {
            s ~= "  [%02s] %08x %s\n".format(i, xyBits[i], xyCounts[i]);
        }
        string s2;
        //foreach(i, v; zValues) s2 ~= "  [%02s] %032b\n".format(i, v);
        return "M6MixedCell(\n%s\n%s)".format(s, s2);
    }
private:
    void unset(uint index) {
        todo();
    }
}

/+
//  [value] 262144 (32*8192)  index / 1
//  [1]     8192   (32*256)   index / 32
//  [0]     256    (32*8)     index / 1024

    uint[8] bits0;  // 256 bits
    uint[8] counts0;

    uint[] bits1;   // 0..8192 bits
    uint[] counts1;

    uint[] values;

    void set(uint index, bool value) {
        assert(index<M6_VOXELS_PER_CELL);
        if(!value) { todo(); return; }

        chat("set %s =========================", index);

        // [0]
        uint a = index / 1024;  // 0..255
        uint n = a/32;          // 0..7
        uint r = index&31;      // 0..31

        const bits1Index = counts0[n] + getImpliedIndex_32bit(bits0[n], r);
        chat("  a: %s, n: %s, r: %s, bits1Index: %s", a, n, r, bits1Index);

        chat("  -->%s", bits0[n] & (1<<r));
        if(0 == (bits0[n] & (1<<r))) {

            // add bits1 and counts1
            bits1.insertAt(bits1Index, 0.as!ushort);
            counts1.insertAt(bits1Index, 0);
            chat("  bits1.length: %s, counts1.length: %s", bits1.length, counts1.length);

            // set bit
            bits0[n] |= (1<<r);
            chat("  bits0: %s", toHexString(bits0));

            // update counts0
            foreach(i; n+1..counts0.length) counts0[i]++;
            chat("  counts0: %s", counts0);
        }


        // [1]
        a = index / 32;     // 0.8191
        n = a/32;           // 0.255
        r = index&31;       // 0..31
        const valuesIndex = counts1[n] + getImpliedIndex_32bit(bits1[n], r);
        chat("  a: %s, n: %s, r: %s, valuesIndex: %s", a, n, r, valuesIndex);

        chat("  -->%s", bits1[n] & (1<<r));
        if(0 == (bits1[n] & (1<<r))) {

            // add values
            values.insertAt(valuesIndex, 0);
            chat("values.length: %s", values.length);

            // set bit
            bits1[n] |= (1<<r);
            chat("  bits1: %s", toHexString(bits1));

            // update counts1
            foreach(i; valuesIndex+1..counts1.length) counts1[i]++;
            chat("  counts1: %s", counts1);
        }

        // [value]
        values[valuesIndex] |= (1<<r);
        chat("  values: %s", toHexString(values));
    }
+/
