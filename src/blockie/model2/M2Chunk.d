module blockie.model2.M2Chunk;

import blockie.model;

final class M2Chunk : Chunk {
public:
    this(chunkcoords coords) {
        super(coords);

        /// Set to air
        voxels.length = 8;
        auto r = root();
        r.flag = M2Flag.AIR;
        r.distance.clear();
    }

    override bool isAir() {
        return root().flag==M2Flag.AIR;
    }

    M2Root* root() { return cast(M2Root*)voxels.ptr; }
}
//------------------------------------------------------------------------------------
enum M2Flag : ubyte { AIR=0, MIXED }

align(1) struct M2Root { align(1):
    M2Flag flag;
    ubyte _reserved;
    Distance6 distance;    /// if flag==AIR

    /// If flag==AIR/SOLID this is not present
    M2Cell[M2_CELLS_PER_CHUNK] cells;

    static assert(M2Root.sizeof==2 + Distance6.sizeof + M2_CELLS_PER_CHUNK*M2Cell.sizeof);

    bool isAir() const   { return flag==M2Flag.AIR; }
    bool isMixed() const { return flag==M2Flag.MIXED; }

    M2Cell* getCell(ubyte* ptr, uint oct) {
        assert(oct<M2_CELLS_PER_CHUNK);
        return cast(M2Cell*)(ptr+8+(oct*M2Cell.sizeof));
    }
    void recalculateFlags() {
        if(allCellsAreAir()) {
            flag = M2Flag.AIR;
        } else {
            flag = M2Flag.MIXED;
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
//------------------------------------------------------------------------------------
align(1) struct M2Cell { align(1):
    ubyte bits;
    union {
        Distance3 distance; /// if bits==0
        Offset3 offset;     /// if bits!=0
                            /// point to 0 to 8 contiguous M2Branches
                            /// (if bits==0xff and offset==0xffffff then cell is solid)
    }
    static assert(M2Cell.sizeof==4);

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

    M2Branch* getBranch(ubyte* ptr, uint oct) {
        assert(oct<8);
        //oct = popcnt(bits & (0x7f >> (7-oct)));
        return cast(M2Branch*)(ptr+(offset.get()*4)+(oct*M2Branch.sizeof));
    }
    string toString() const {
        if(isAir) return "AIR(%s)".format(distance);
        if(isSolid) return "SOLID";
        return "%08b @ %s".format(bits, offset);
    }
}
//------------------------------------------------------------------------------------
align(1) struct M2Branch { align(1):
    ubyte bits;
    Offset3 offset; /// point to 0 to 8 contiguous M2Branches

    static assert(M2Branch.sizeof==4);

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
    M2Branch* getBranch(ubyte* ptr, uint oct) {
        assert(oct<8);

        //oct = popcnt(bits & (0x7f >> (7-oct)));
        return cast(M2Branch*)(ptr+(offset.get()*4)+(oct*M2Branch.sizeof));
    }
    M2Leaf* getLeaf(ubyte* ptr, uint oct) {
        assert(oct<8);
        //oct = popcnt(bits & (0x7f >> (7-oct)));
        return cast(M2Leaf*)(ptr+(offset.get()*4)+(oct*M2Leaf.sizeof));
    }
    string toString() {
        if(isAir) return "AIR";
        if(isSolid) return "SOLID";
        return "%08b @ %s".format(bits, offset);
    }
}
//------------------------------------------------------------------------------------
align(1) struct M2Leaf { align(1):
    ubyte bits;   /// 1 bit per voxel
    static assert(M2Leaf.sizeof==1);

    bool isSolid() const { return bits==0xff; }

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
//------------------------------------------------------------------------------------
