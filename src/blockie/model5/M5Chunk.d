module blockie.model5.M5Chunk;

import blockie.model;

/**
 *  De-optimised M5 voxel layout.
 *
 * CHUNK_SIZE       == 1024
 * OCTREE_ROOT_BITS == 4
 *
 *      M5Root                  }
 *          4096 * M5CellL4     } 4 bits (Points to 0..4096 M5CellL3)
 *
 *      M5Level5                }
 *          64 * M5Cell2        } 2 bits (Points to 0..64 )
 *
 *      M5Level3                }
 *          64 * M5Branch       } 2 bits
 *
 *      M5Level2                }
 *          8 * M5Leaf          } 1 bit
 *
 *      M5Leaf                  }
 *          8 bit flags         } 1 bit

    Level   | Bits         | Contains                     | Count         | Volume                 |
    --------+--------------+------------------------------+---------------+------------------------|
      chunk | 11_1111_1111 | 1 M5Root                     |             1 | 1024^3 = 1,073,741,824 |
     root 4 | 11_1100_0000 | 4096 M5CellL4  --> M5CellL3  |         4,096 |   32^3 =        32,768 |
          3 |      11_0000 | 0..64 M5CellL3               |     2,097,152 |    8^3 =           512 |
          2 |         1100 | 0..64 M5CellL2               |    16,777,216 |    4^3 =            64 |
          1 |           10 | 0..8 M3Leaves                |   134,217,728 |    2^3 =             8 |
          0 |            1 | 8 bits                       | 1,073,741,824 |      1 =             1 |

    M5Chunk:

    M5Root {
        M5L4[4096] (11_1100_0000) {
            0..4086 * M5L3[64] (11_0000) {
                0..64 * M5L2[64] (1100) {

                }
            }
        }
    }

    M5Root
    1 } 4096 * M5SubCell1
    1 }
    1 }
    1 }      Each M5SubCell1
    0        1 } 64 * M5SubCell2
    0        1 }             Each M5SubCell2
    0        0               1 } 64 * M5SubCell3
    0        0               1 }           Each M5SubCell3
    0        0               0             1 } 8 * M5Leaf   M5Leaf
    0        0               0             0                1

*/
final class M5Chunk : Chunk {
public:
    this(chunkcoords coords) {
        super(coords);

        /// Set to air
        voxels.length = 8;
        auto r = root();
        r.flag = M5Flag.AIR;
        r.distance.clear();
    }

    override bool isAir() { return root().isAir(); }

    M5Root* root() { return cast(M5Root*)voxels.ptr; }
}

enum M5Flag : ubyte { AIR=0, OCTREES }

align(1):

/**
 * M5Root contains exactly 4096 M5SubCell1s
 */
struct M5Root { static assert(M5Root.sizeof==8 + M5_CELLS_PER_CHUNK*M5SubCell1.sizeof); align(1):
    M5Flag flag;
    ubyte _reserved;
    Distance6 distance;                     // Only used if flag==AIR

    M5SubCell1[M5_CELLS_PER_CHUNK] cells;   // If flag==AIR this is not present

    bool isAir() { return flag==M5Flag.AIR; }

    M5SubCell1* getCell(ubyte* ptr, uint oct) {
        ASSERT(oct<M5_CELLS_PER_CHUNK);
        return cast(M5SubCell1*)(ptr+8+(oct*M5SubCell1.sizeof));
    }
    void allEditsComplete(ubyte* ptr) {
        if(allCellsAreAir()) {
            flag = M5Flag.AIR;
        } else {
            flag = M5Flag.OCTREES;
        }
        calculateSolid(ptr);
    }

    string toString() {
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
    void calculateSolid(ubyte* ptr) {
        for(auto i=0;i<M5_CELLS_PER_CHUNK;i++) {
            getCell(ptr, i).calculateSolid(ptr);
        }
    }
}
/**
 * Each active M5Cell64_1 points to 0..64 M5SubCell2s
 */
struct M5SubCell1 { static assert(M5SubCell1.sizeof==12); align(1):
    enum NUMBITS = 64;
    ulong bits;         // 64 possible M5Cell64_2s

    union {
        Distance4 distance; // if isAir
        Offset4 offset;     // if bits!=0, // point to 0 to 64 contiguous M5SubCell2s
    }

    bool isAir()       { return bits==0L; }
    bool isSolid()     { return offset.get()==0xffff_ffff; } /// special flag
    uint numBranches() { return popcnt(bits); }

    bool isAir(uint oct)    { ASSERT(oct<NUMBITS); return (bits & (1L<<oct))==0; }
    bool isBranch(uint oct) { return !isAir(oct); } // && !isSolid(); }

    //void setToAir(uint oct) { ASSERT(oct<64); bits &= ~(1L<<oct); }
    //void setToSolid()       { bits = 0xff; offset.set(0xffff_ffff); }
    void setToBranch(uint oct) { ASSERT(oct<NUMBITS); bits |= (1L<<oct); }

    M5SubCell2* getCell(ubyte* ptr, uint oct) {
        ASSERT(oct<NUMBITS);
        return cast(M5SubCell2*)(ptr+(offset.get()*4)+(oct*M5SubCell2.sizeof));
    }
    string toString() {
        return "M5SubCell1(%soffset=%s)".format(isAir ? "AIR":"", offset);
    }
private:
    void calculateSolid(ubyte* ptr) {
        if(bits!=0xffff_ffff) return;

        for(auto i=0;i<NUMBITS;i++) {
            auto c = getCell(ptr, i);
            c.calculateSolid(ptr);
            if(!c.isSolid()) return;
        }
        offset.set(0xffff_ffff);
    }
}
/**
 * Each M5Cell64_2 points to 0..64 M5Cell8s
 */
struct M5SubCell2 { static assert(M5SubCell2.sizeof==12); align(1):
    enum NUMBITS = 64;
    ulong bits;         // 64 possible M5Cell8s
    Offset4 offset;     // point to 0 to 64 contiguous M5SubCell3s

    bool isAir()       { return bits==0L; }
    bool isSolid()     { return offset.get()==0xffff_ffff; } /// special flag
    uint numBranches() { return popcnt(bits); }

    bool isAir(uint oct)    { ASSERT(oct<NUMBITS); return (bits & (1L<<oct))==0; }
    bool isBranch(uint oct) { return !isAir(oct); } // && !isSolid(); }

    //void setToAir()         { bits = 0; offset.set(0); }
    //void setToAir(uint oct) { ASSERT(oct<NUMBITS); bits &= ~(1L<<oct); }
    //void setToSolid()       { bits = 0xff; offset.set(0xffff_ffff); }
    void setToBranch(uint oct) { ASSERT(oct<NUMBITS); bits |= (1L<<oct); }

    M5SubCell3* getCell(ubyte* ptr, uint oct) {
        ASSERT(oct<NUMBITS);
        return cast(M5SubCell3*)(ptr+(offset.get()*4)+(oct*M5SubCell3.sizeof));
    }
    bool equals(ubyte* ptr, M5SubCell2* other) {
        if(bits != other.bits) return false;
        for(auto i=0; i<NUMBITS; i++) {
            if(isBranch(i)) {
                if(!getCell(ptr, i).equals(ptr, other.getCell(ptr,i))) return false;
            }
        }
        return true;
    }
    string toString() {
        return "M5SubCell2(%soffset=%s)".format(isAir ? "AIR":"", offset);
    }
private:
    void calculateSolid(ubyte* ptr) {
        if(bits!=0xffff_ffff) return;

        for(auto i=0;i<NUMBITS;i++) {
            auto c = getCell(ptr, i);
            c.calculateSolid(ptr);
            if(!c.isSolid()) return;
        }
        offset.set(0xffff_ffff);
    }
}
/**
 * Each M5SubCell3 points to 0..8 M5Leafs
 */
struct M5SubCell3 { static assert(M5SubCell3.sizeof==8); align(1):
    enum NUMBITS = 8;
    ubyte bits;         // 8 possible M5Leafs
    ubyte[3] _reserved;
    Offset4 offset;     // point to 0 to 8 contiguous M5Leafs

    bool isAir()       { return bits==0; }
    bool isSolid()     { return offset.get()==0xffff_ffff; } /// special flag
    uint numBranches() { return popcnt(bits); }

    bool isAir(uint oct)    { ASSERT(oct<NUMBITS); return (bits & cast(ubyte)(1<<oct))==0; }
    bool isBranch(uint oct) { return !isAir(oct); } // && !isSolid(); }

    //void setToAir()            { bits = 0; offset.set(0); }
    void setToBranch(uint oct) { ASSERT(oct<NUMBITS); bits |= cast(ubyte)(1<<oct); }

    M5Leaf* getLeaf(ubyte* ptr, uint oct) {
        ASSERT(oct<NUMBITS);
        return cast(M5Leaf*)(ptr+(offset.get()*4)+(oct*M5Leaf.sizeof));
    }
    ulong getAllLeafBits(ubyte* ptr) {
        ulong n;
        for(auto i=0; i<8; i++) {
            n <<= 8;
            if(isBranch(i)) {
                n |= getLeaf(ptr, i).bits;
            }
        }
        return n;
    }
    bool equals(ubyte* ptr, M5SubCell3* other) {
        if(bits!=other.bits) return false;
        return getAllLeafBits(ptr) == other.getAllLeafBits(ptr);
    }
    string toString() {
        return "M5SubCell3(%soffset=%s)".format(isAir ? "AIR":"", offset);
    }
private:
    void calculateSolid(ubyte* ptr) {
        if(bits!=0xff) return;
        for(auto i=0;i<NUMBITS;i++) {
            if(!getLeaf(ptr, i).isSolid()) return;
        }
        offset.set(0xffff_ffff);
    }
}
/**
 * Each M5Leaf contains 8 bits
 */
struct M5Leaf { static assert(M5Leaf.sizeof==1); align(1):
    ubyte bits;   /// 1 bit per voxel

    bool isSolid()            { return bits==0xff; }
    void setToAir()           { bits = 0; }
    void unsetVoxel(uint oct) { ASSERT(oct<8); bits &= cast(ubyte)~(1<<oct); }
    void setVoxel(uint oct)   { ASSERT(oct<8); bits |= cast(ubyte)(1<<oct); }
    string toString()         { return "M5Leaf(%08b)".format(bits); }
}
