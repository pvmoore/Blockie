module blockie.model1.M1Chunk;

import blockie.all;
import blockie.model.Chunk;
/**
 *  y    z
 *  |   /----------
 *  |  /  2 /  3 /
 *  | /----------
 *  |/  0 /  1 /
 *  |----------x
 */
final class M1Chunk : Chunk {
public:
    /// Creates an air chunk
    this(chunkcoords coords) {
        super(coords);

        /// Set to air
        voxels.length = OctreeFlags.sizeof;
        this.root().flags.flag = OctreeFlag.AIR;
    }

    override bool isAir() {
        return root().flags.flag==OctreeFlag.AIR;
    }
    override bool isAirCell(uint cellIndex) {
        assert(cellIndex<M1_CELLS_PER_CHUNK);
        return optimisedRoot().isAir(cellIndex);
    }
    override void setDistance(ubyte x, ubyte y, ubyte z) {
        auto r = root();
        r.flags.distX = x;
        r.flags.distY = y;
        r.flags.distZ = z;
    }
    override void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z) {
        assert(cell<M1_CELLS_PER_CHUNK);
        assert(isAirCell(cell), "%s %s".format(pos, cell));

        auto r = optimisedRoot();
        r.setDField(cell, x,y,z);
    }
    override void setCellDistance(uint cell, DFieldsBi df) {
       throw new Error("Not implemented");
    }

    OctreeRoot* root()             { return cast(OctreeRoot*)voxels.ptr; }
    OptimisedRoot* optimisedRoot() { return cast(OptimisedRoot*)voxels.ptr; }
}
//-----------------------------------------------------------------------------------
enum OctreeFlag : ubyte {
    NONE  = 0,
    AIR   = 1,
    MIXED = 2
}
align(1) final struct OctreeFlags { align(1):
    OctreeFlag flag;
    ubyte distX;
    ubyte distY;
    ubyte distZ;

    static assert(OctreeFlags.sizeof==4);
}

final struct OctreeRoot {
    OctreeFlags flags;
    ubyte[M1_CELLS_PER_CHUNK/8] bits;
    OctreeIndex[M1_CELLS_PER_CHUNK] indexes;
    Distance3[M1_CELLS_PER_CHUNK] cellDistances;

    static assert(OctreeRoot.sizeof==OctreeFlags.sizeof+512+OctreeIndex.sizeof*4096+
                  Distance3.sizeof*M1_CELLS_PER_CHUNK); // 25092

    bool isAirCell(uint cell) {
        return isSolid(cell) && indexes[cell].voxel()==0;
    }

    uint numOffsets() {
        uint count = 0;
        foreach(b; bits) count += popcnt(b);
        return count;
    }
    bool getBit(uint i) {
        static if(bits.length==1) {
            return (bits[0] & (1<<i)) !=0;
        } else {
            const byteIndex = i>>3;
            const bitIndex  = i&7;
            return (bits[byteIndex] & (1<<bitIndex)) !=0;
        }
    }
    void setBit(uint i, bool value) {
        static if(bits.length==1) {
            const byteIndex = 0;
            const bitIndex  = i;
        } else {
            const byteIndex = i>>3;
            const bitIndex  = i&7;
        }
        if(value) {
            bits[byteIndex] |= cast(ubyte)(1<<bitIndex);
        } else {
            //bits[byteIndex] &= ~cast(ubyte)(1<<bitIndex);
            bits[byteIndex] &= cast(ubyte)~(1<<bitIndex);
        }
    }
    ubyte getVoxel(uint oct) {
        return indexes[oct].voxel;
    }
    void setVoxel(uint oct, ubyte v) {
        // set to solid voxel
        setBit(oct, false);
        indexes[oct].set(v);
    }
    uint getOffset(uint oct) {
        return indexes[oct].offset;
    }
    void setOffset(uint oct, uint offset) {
        // set to index
        setBit(oct, true);
        indexes[oct].offset = offset;
    }
    bool bitsIsZero() {
        static if(bits.length==1) {
            return bits[0]==0;
        } else static if(bits.length==8) {
            return (cast(ulong*)bits.ptr)[0]==0;
        } else {
            return isZeroMem(bits.ptr, bits.length);
        }
    }
    bool isSolid(uint oct) {
        return getBit(oct)==0;
    }
    bool isSolid() {
        if(!bitsIsZero()) return false;
        ubyte v = indexes[0].voxel;
        return onlyContains(indexes.ptr, indexes.length*OctreeIndex.sizeof, v);
    }
    bool isSolidAir() {
        return flags.flag==OctreeFlag.AIR;
    }
    void setToSolid(ubyte v) {
        bits[] = 0;
        foreach(ref i; indexes) {
            i.set(v);
        }
    }
    void recalculateFlags() {
        if(indexes[0].voxel==V_AIR && bitsIsZero() && isSolid()) {
            flags.flag = OctreeFlag.AIR;
        } else {
            flags.flag = OctreeFlag.MIXED;
        }
    }
}
// ----------------------------------------------------------
static assert(OctreeTwig.sizeof==12);
final struct OctreeTwig {
    ubyte bits;
    ubyte[3] baseIndex;
    ubyte[8] voxels;

    uint getBaseIndex() {
        return (baseIndex[2]<<16) | (baseIndex[1]<<8) | baseIndex[0];
    }
    void setBaseIndex(uint b) {
        baseIndex[0] = cast(ubyte)(b&0xff);
        baseIndex[1] = cast(ubyte)(b>>8)&0xff;
        baseIndex[2] = cast(ubyte)(b>>16)&0xff;
    }
}
// ----------------------------------------------------------
static assert(OctreeBranch.sizeof==25);
final struct OctreeBranch {
    ubyte bits;
    OctreeIndex[8] indexes;

    uint numOffsets() {
        return popcnt(bits);
    }
    ubyte getVoxel(uint oct) {
        return indexes[oct].voxel;
    }
    void setVoxel(uint oct, ubyte v) {
        //bits &= ~cast(ubyte)(1<<oct);
        bits &= cast(ubyte)~(1<<oct);
        indexes[oct].set(v);
    }
    uint getOffset(uint oct) {
        return indexes[oct].offset;
    }
    void setOffset(uint oct, uint offset) {
        bits |= cast(ubyte)(1<<oct);
        indexes[oct].offset = offset;
    }
    bool isSolid() {
        if(bits!=0) return false;
        ubyte v = getVoxel(0);
        for(auto i=1;i<8;i++) if(indexes[i].voxel!=v) return false;
        return true;
    }
    bool isSolid(uint oct) {
        return 0==(bits & (1<<oct));
    }
    void setToSolid(ubyte v) {
        bits = 0;
        foreach(ref i; indexes) {
            i.set(v);
        }
    }
}
// ----------------------------------------------------------
static assert(OctreeLeaf.sizeof==8);
final struct OctreeLeaf {
    ubyte[8] voxels;

    ubyte getVoxel(uint oct) {
        return voxels[oct];
    }
    bool isSolid() {
        ubyte v = getVoxel(0);
        for(auto i=1; i<voxels.length; i++) {
            if(getVoxel(i)!=v) return false;
        }
        return true;
    }
    void setVoxel(uint oct, ubyte v) {
        voxels[oct] = v;
    }
    void setAllVoxels(ubyte v) {
        voxels[] = v;
    }
}
// ----------------------------------------------------------
static assert(OctreeIndex.sizeof==3);
final struct OctreeIndex {
    ubyte[3] v;

    ubyte voxel() {
        return v[0];
    }
    void set(ubyte voxel) {
        v[0] = voxel;
        v[1] = 0;
        v[2] = OctreeFlag.NONE;
    }
    uint offset() {
        return (v[2]<<16) | (v[1]<<8) | v[0];
    }
    void offset(uint o) {
        v[0] = cast(ubyte)(o&0xff);
        v[1] = cast(ubyte)(o>>8)&0xff;
        v[2] = cast(ubyte)(o>>16)&0xff;
    }
}