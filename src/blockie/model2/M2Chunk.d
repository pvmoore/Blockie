module blockie.model2.M2Chunk;

import blockie.all;

///
/// Assumes CHUNK_SIZE       == 1024
///         OCTREE_ROOT_BITS == 4
///

private const NUM_CELLS = 4096;

final class M2Chunk : Chunk {
public:
    this(chunkcoords coords) {
        super(coords);

        /// Set to air
        voxels.length = 4;
        auto r = root();
        r.flag       = M2Flag.AIR;
        r.distance.x = 0;
        r.distance.y = 0;
        r.distance.z = 0;
    }

    override bool isAir() {
        return root().flag==M2Flag.AIR;
    }
    override bool isAirCell(uint cellIndex) {
        assert(cellIndex<NUM_CELLS, "%s".format(cellIndex));
        return root().cells[cellIndex].isAir();
    }
    override void setDistance(ubyte x, ubyte y, ubyte z) {
        auto r = root();
        r.distance.x = x;
        r.distance.y = y;
        r.distance.z = z;
    }
    override void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z) {
        assert(cell<NUM_CELLS);
        auto c = root().getCell(voxels.ptr, cell);
        assert(!isAir);
        assert(voxels.length>4, "voxels.length=%s".format(voxels.length));
        assert(c.isAir, "oct=%s bits=%s".format(cell, c.bits));

        c.distance.x = x;
        c.distance.y = y;
        c.distance.z = z;
    }
    override void setCellDistance(uint cell, DFieldsBi f) {

        // Max = 15
        int convert(int v) { return min(v, 15); }

        setCellDistance(cell,
            cast(ubyte)((convert(f.x.up)<<4) | convert(f.x.down)),
            cast(ubyte)((convert(f.y.up)<<4) | convert(f.y.down)),
            cast(ubyte)((convert(f.z.up)<<4) | convert(f.z.down))
        );
    }

    M2Root* root() { return cast(M2Root*)voxels.ptr; }
}
//------------------------------------------------------------------------------------
enum M2Flag : ubyte { AIR=0, MIXED }

align(1) struct M2Root { align(1):
    M2Flag flag;
    M2Distance distance;    /// if flag==AIR

    /// If flag==AIR/SOLID this is not present
    M2Cell[NUM_CELLS] cells;

    static assert(M2Root.sizeof==1 + M2Distance.sizeof + NUM_CELLS*M2Cell.sizeof);

    bool isAir() const   { return flag==M2Flag.AIR; }
    bool isMixed() const { return flag==M2Flag.MIXED; }

    M2Cell* getCell(ubyte* ptr, uint oct) {
        assert(oct<NUM_CELLS);
        return cast(M2Cell*)(ptr+4+(oct*M2Cell.sizeof));
    }
    bool allCellsAreSolid() {
        foreach(cell; cells) {
            if(!cell.isSolid) return false;
        }
        return true;
    }

    string toString() const {
        if(isAir) return "AIR(%s)".format(distance);
        return "MIXED";
    }
}
//------------------------------------------------------------------------------------
align(1) struct M2Cell { align(1):
    ubyte bits;
    union {
        M2Distance distance;/// if bits==0
        M2Offset offset;    /// if bits!=0
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
    M2Offset offset; /// point to 0 to 8 contiguous M2Branches

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
align(1) struct M2Offset { align(1):
    ubyte[3] v;
    static assert(M2Offset.sizeof==3);

    uint get() const { return (v[2]<<16) | (v[1]<<8) | v[0]; }
    void set(uint o) {
        assert(o <= 0xffffff);
        v[0] = cast(ubyte)(o&0xff);
        v[1] = cast(ubyte)((o>>8)&0xff);
        v[2] = cast(ubyte)((o>>16)&0xff);
    }
    string toString() const { return "%s".format(get()*4); }
}
//------------------------------------------------------------------------------------
align(1) struct M2Distance { align(1):
    ubyte x,y,z;

    static assert(M2Distance.sizeof==3);
    string toString() const { return "%s,%s,%s".format(x,y,z); }
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
