module blockie.model4.M4Chunk;

import blockie.all;

///
/// voxels:
///     M4Root:
///         Flag (1 byte)               \
///         reserved (1 byte)           | Minimum root
///         Chunk distances (6 bytes)   /
///
///         Bits (level 1 to 7)
///         Level 7 Popcounts
///
///     M4Branches (8^^3 blocks)
///          bits (1 byte)
///
///          100  2 M4Branch    --> point to 1..8 M4Leaf
///           10  1 M4Leaf      --> Each leaf contains 8 bits
///            1  0 Bit in M4Leaf

final class M4Chunk : Chunk {
public:
    this(chunkcoords coords) {
        super(coords);

        /// Set to air
        voxels.length = 8;
        auto r = root();
        r.flag = M4Root.Flag.AIR;
        r.distance.clear();
    }

    override bool isAir() { return root().isAir(); }

    M4Root* root() { return cast(M4Root*)voxels.ptr; }
}
//======================================================================================
align(1) struct M4Root { align(1):
    enum Flag : ubyte {
        AIR    = 0,      /// M4Root size will be 8
        OCTREE = 1
    }

    Flag flag;
    ubyte _reserved;
    Distance6 distance; /// Only used if flag==AIR

    /// (calculated when this root is read-optimised)
    uint[M4_CELLS_PER_CHUNK/32] l7popcounts;    // 262144 bytes

    ubyte[M4_CELLS_PER_CHUNK/8] l7bits; // 262144 bytes

    /// Octree flags (Levels 1 to 6)
    ubyte[37452] bits;
    //-----------------------------------------------------------------------------------
    static assert(bits.sizeof        == 4684+32768);
    static assert(l7popcounts.sizeof == 262144);
    static assert(l7bits.sizeof      == 262144);
    static assert(M4Root.sizeof      == 8 + 262144 + 262144 + 37452);
    //-----------------------------------------------------------------------------------
    __gshared static immutable uint[] BITS_OFFSET = [
        uint.max,
        0,//0,      /// [1] = 2^^3   = 8 bits      (1 byte)
        4,//1,      /// [2] = 4^^3   = 64 bits     (8 bytes)
        12,//9,      /// [3] = 8^^3   = 512 bits    (64 bytes)
        76,//73,     /// [4] = 16^^3  = 4096 bits   (512 bytes)
        588,//585,    /// [5] = 32^^3  = 32768 bits  (4096 bytes)
        4684//4681,   /// [6] = 64^^3  = 262144 bits (32768 bytes)
    ];
    //-----------------------------------------------------------------------------------
    bool isAir() { return flag==Flag.AIR; }

    void setToOctrees() {
        this.flag = Flag.OCTREE;
        this.distance.clear();
    }

    /// Check bit at level 7
    bool isAirCell(uint cell) {
        expect(cell < M4_CELLS_PER_CHUNK);

        const b = l7bits[cell/8];
        return (b & (1u<<(cell&7))) == 0;
    }
    bool isAirCell(uint cell, uint level) {
        expect(cell < (1<<level)^^3);
        return (bits[BITS_OFFSET[level] + cell/8] & (1u<<(cell&7))) == 0;
    }
    void setCellToAir(uint cell) {
        throw new Error("Implement me");
    }
    void setCellToNonAir(uint cell) {
        l7bits[cell/8] |= (1u<<(cell&7));
    }
    void recalculateFlags() {
        /// Scan level 7 bits because these are the only ones guaranteed to be correct
        if(isZeroMem(l7bits.ptr, M4_CELLS_PER_CHUNK/8)) {
            flag = Flag.AIR;
        } else {
            flag = Flag.OCTREE;
        }
    }
    void calculateLevel1To6Bits() {
        bits[] = 0;

        for(uint cell = 0; cell<M4_CELLS_PER_CHUNK; cell++) {

            if(!isAirCell(cell)) {
                uint3 p = uint3(
                    cell & 0b1111111,
                    (cell >>> 7) & 0b1111111,
                    (cell >>> 14) & 0b1111111
                );
                expect((p.x | (p.y<<7) | (p.z<<14)) ==cell);

                for(int i = 6; i>0; i--) {
                    p >>>= 1;

                    uint j = p.x | (p.y<<i) | (p.z<<(i+i));

                    bits[BITS_OFFSET[i] + j/8] |= (1u<<(j&7));
                }
            }
        }
    }
    void calculateL7Popcounts() {
        uint* bitsPtr = cast(uint*)(l7bits.ptr);
        uint sum = 0;
        for(auto i=0; i<l7popcounts.length; i++) {
            sum           += popcnt(*bitsPtr++);
            l7popcounts[i] = sum;
        }
    }
    string toString() { return "Root(%s)".format(isAir?"AIR":"OCTREE"); }
}
//---------------------------------------------------------------------------------
align(1)  struct M4Cell { align(1):
    ubyte bits;
    Offset4 offset;
    static assert(M4Cell.sizeof==5);

    bool isAir()            { return bits==0; }
    //bool isSolid()          { return bits==0xff && offset.get()==0xff_ffff; } /// special flag
    uint numBranches()      { return popcnt(bits); }
    bool isAir(uint oct)    { return (bits & (1u<<oct))==0; }
    bool isBranch(uint oct) { return !isAir(oct); }

    void setToAir() {
        bits = 0;
    }
    //void setToSolid() {
    //    bits = 0xff;
    //    offset.set(0xffffff);
    //}
    void setToBranches(uint oct) {
        expect(oct<8);
        bits |= cast(ubyte)(1u<<oct);
    }
}
//---------------------------------------------------------------------------------
align(1) struct M4Branch { align(1):
    ubyte bits;
    Offset4 offset; /// point to 0..8 contiguous M4Leafs
    static assert(M4Branch.sizeof==5);

    bool isAir()     { return bits==0; }
    //bool isSolid()   { return bits==0xff && offset.get()==0xffff_ffff; } /// special flag
    //bool isMixed()   { return !isAir && !isSolid; }
    uint numLeaves() { return popcnt(bits); }

    bool isAir(uint oct)  { return (bits & (1u<<oct))==0; }
    bool isLeaf(uint oct) { return !isAir(oct); }

    //bool allLeavesAreSolid(ubyte* ptr) {
    //    if(bits!=0xff) return false;
    //
    //    auto leaf = getLeaf(ptr, 0);
    //
    //    for(int i=0; i<8; i++) {
    //        if(!leaf.isSolid) return false;
    //        leaf++;
    //    }
    //    return true;
    //}
    //bool allBranchesAreSolid(ubyte* ptr) {
    //    if(bits!=0xff) return false;
    //
    //    auto br = getBranch(ptr, 0);
    //
    //    for(int i=0; i<8; i++) {
    //        if(!br.isSolid) return false;
    //        br++;
    //    }
    //    return true;
    //}

    void setToAir() {
        bits = 0;
    }
    //void setToSolid() {
    //    bits = 0xff;
    //    offset.set(0xffffff);
    //}
    void setToLeaf(uint oct) {
        expect(oct<8);
        bits |= cast(ubyte)(1u<<oct);
    }

    string toString() {
        if(isAir) return "AIR";
        //if(isSolid) return "SOLID";
        return "%08b @ %s".format(bits, offset);
    }
}
//------------------------------------------------------------------------------------
align(1) struct M4Leaf { align(1):
    ubyte bits;   /// 1 bit per voxel
    static assert(M4Leaf.sizeof==1);

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
