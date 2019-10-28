module blockie.model3.M3Chunk;

import blockie.all;

///
/// Assumes CHUNK_SIZE       == 1024
///         OCTREE_ROOT_BITS == 5
///

final class M3Chunk : Chunk {
public:
    this(chunkcoords coords) {
        super(coords);

        /// Set to air
        voxels.length = 8;
        auto r = root();
        r.flag = M3Flag.AIR;
        r.distance.clear();
    }

    override bool isAir() {
        return root().flag==M3Flag.AIR;
    }

    M3Root* root() { return cast(M3Root*)voxels.ptr; }
}

enum M3Flag : ubyte { AIR=0, MIXED }

align(1):

struct M3Root {
    static assert(M3Root.sizeof==2 + Distance6.sizeof + M3_CELLS_PER_CHUNK*M3Cell.sizeof);
align(1):
    M3Flag flag;
    ubyte _reserved;
    Distance6 distance;    // if flag==AIR

    M3Cell[M3_CELLS_PER_CHUNK] cells;   // If flag==AIR/SOLID this is not present
    //-----------------------------------------------------------------------------------

    bool isAir() const   { return flag==M3Flag.AIR; }
    bool isMixed() const { return flag==M3Flag.MIXED; }

    M3Cell* getCell(ubyte* ptr, uint oct) {
        assert(oct<M3_CELLS_PER_CHUNK);
        return cast(M3Cell*)(ptr+8+(oct*M3Cell.sizeof));
    }
    void recalculateFlags() {
        if(allCellsAreAir()) {
            flag = M3Flag.AIR;
        } else {
            flag = M3Flag.MIXED;
        }
    }
    string toString() const {
        if(isAir) return "AIR(%s)".format(distance);
        return "MIXED";
    }
private:
    bool allCellsAreAir() {
        foreach(c; cells) {
            if(!c.isAir) return false;
        }
        return true;
    }
}

struct M3Cell { static assert(M3Cell.sizeof==4); align(1):
    ubyte bits;
    union {
        Distance3 distance; // if isAir
        Offset3 offset;     // if bits!=0 point to 0 to 8 contiguous M3Branches
        // (if bits==0xff and offset==0xffffff then cell is solid)
    }
    //-----------------------------------------------------------------------------------

    bool isAir() const             { return bits==0; }
    bool isSolid() const           { return bits==0xff && offset.get()==0xff_ffff; } /// special flag
    bool isMixed() const           { return !isAir && !isSolid; }
    uint numBranches() const       { return popcnt(bits); }

    bool isAir(uint oct) const     { assert(oct<8); return (bits & (1<<oct))==0; }
    bool isBranch(uint oct) const  { return !isAir(oct); } // && !isSolid(); }

    void setToAir(uint oct) {
        assert(oct<8);
        bits &= cast(ubyte)~(1<<oct);
    }
    void setToSolid() {
        bits = 0xff;
        offset.set(0xffffff);
    }
    void setToBranch(uint oct) {
        assert(oct<8);
        bits |= cast(ubyte)(1<<oct);
    }
    bool allBranchesAreSolid(ubyte* ptr) {
        if(bits!=0xff) return false;

        auto br = getBranch(ptr, 0);

        for(int i=0; i<8; i++) {
            if(!br.isSolid) return false;
            br++;
        }
        return true;
    }

    M3Branch* getBranch(ubyte* ptr, uint oct) {
        assert(oct<8);
        //oct = popcnt(bits & (0x7f >> (7-oct)));
        return cast(M3Branch*)(ptr+(offset.get()*4)+(oct*M3Branch.sizeof));
    }
    string toString() const {
        if(isAir) return "AIR(%s)".format(distance);
        if(isSolid) return "SOLID";
        return "%08b @ %s".format(bits, offset);
    }
}

struct M3Branch { static assert(M3Branch.sizeof==4); align(1):
    ubyte bits;
    Offset3 offset; // point to 0 to 8 contiguous M3Branches
    //-----------------------------------------------------------------------------------

    bool isAir() const             { return bits==0; }
    bool isSolid() const           { return bits==0xff && offset.get()==0xff_ffff; } /// special flag
    bool isMixed() const           { return !isAir && !isSolid; }
    uint numBranches() const       { return popcnt(bits); }

    bool isAir(uint oct) const     { assert(oct<8); return (bits & (1<<oct))==0; }
    bool isBranch(uint oct) const  { return !isAir(oct); }// && !isSolid; }

    bool allLeavesAreSolid(ubyte* ptr) {
        if(bits!=0xff) return false;

        auto leaf = getLeaf(ptr, 0);

        for(int i=0; i<8; i++) {
            if(!leaf.isSolid) return false;
            leaf++;
        }
        return true;
    }
    bool allBranchesAreSolid(ubyte* ptr) {
        if(bits!=0xff) return false;

        auto br = getBranch(ptr, 0);

        for(int i=0; i<8; i++) {
            if(!br.isSolid) return false;
            br++;
        }
        return true;
    }

    void setToAir() {
        bits = 0;
    }
    void setToSolid() {
        bits = 0xff;
        offset.set(0xffffff);
    }
    void setToBranch(uint oct) {
        assert(oct<8);
        bits |= cast(ubyte)(1<<oct);
    }
    M3Branch* getBranch(ubyte* ptr, uint oct) {
        assert(oct<8);

        //oct = popcnt(bits & (0x7f >> (7-oct)));
        return cast(M3Branch*)(ptr+(offset.get()*4)+(oct*M3Branch.sizeof));
    }
    M3Leaf* getLeaf(ubyte* ptr, uint oct) {
        assert(oct<8);
        //oct = popcnt(bits & (0x7f >> (7-oct)));
        return cast(M3Leaf*)(ptr+(offset.get()*4)+(oct*M3Leaf.sizeof));
    }
    string toString() {
        if(isAir) return "AIR";
        if(isSolid) return "SOLID";
        return "%08b @ %s".format(bits, offset);
    }
}

struct M3Leaf { static assert(M3Leaf.sizeof==1); align(1):
    ubyte bits;   // 1 bit per voxel
    //-----------------------------------------------------------------------------------

    bool isSolid() const {
        return bits==0xff;
    }
    void setToAir() {
        bits = 0;
    }
    void unsetVoxel(uint oct) {
        assert(oct<8);
        bits &= cast(ubyte)~(1<<oct);
    }
    void setVoxel(uint oct) {
        assert(oct<8);
        bits |= cast(ubyte)(1<<oct);
    }
    string toString() const { return "%08b".format(bits); }
}
