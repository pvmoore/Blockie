module blockie.model3.M3bTest;

import blockie.model;

/**
 * For testing Model3b
 */
final class M3bTest {
private:
    M3ChunkEditView editView;
    ubyte[] optView;
public:
    this(M3ChunkEditView editView, ubyte[] optView) {
        this.editView = editView;
        this.optView = optView;
    }
    void test() {
        //
        if(editView.isAir()) return;

        //if(editView.getChunk().pos != chunkcoords(0,0,0)) return;

        writefln("TEST: Testing %s", editView);

        static if(false) {
            auto offset = uint3(256, 298, 0);
            bool r1 = getEditVoxel(offset);
            bool r2 = getOptVoxel(offset);

            writefln("%s %s", r1, r2);
        }

        static if(true)
        foreach(z; 0..CHUNK_SIZE) {
            foreach(y; 0..CHUNK_SIZE) {
                foreach(x; 0..CHUNK_SIZE) {

                    auto offset = uint3(x,y,z);

                    bool a = getEditVoxel(offset);
                    bool b = getOptVoxel(offset);

                    if(a!=b) {
                        throw new Exception("Error at %s".format(offset));
                    }
                }
            }
        }
        writefln("TEST passed");
    }

    bool getEditVoxel(uint3 offset) {
        return editView.getVoxel(offset);
    }

    /**
      * Header
      *      [00000] M3Flag, 3 reserved bytes (4 bytes)
      *      [00004] Cell solid flags         (4096 bytes) 1 = solid cell, 0 = air or mixed
      *      [04100] Cell bit flags           (4096 bytes) 0 = air, 1 = mixed
      *      [08196] Cell flag pop counts     (4092 bytes)
      *      [12288] PopcountsA offset        (4 bytes)
      *      [12292] PopcountsB offset        (4 bytes)
      *      [12296] PopcountsC offset        (4 bytes)
      *      [12300] BitsA offset             (4 bytes)
      *      [12304] BitsB offset             (4 bytes)
      *      [12308] BitsC offset             (4 bytes)
      *      [12312] offsetIndexes            (4 bytes)
      *      [12316] offsetLeaves             (4 bytes)
      *      [12320] numIndexBits             (4 bytes)
      * [12324] End of Header
      *
      * [12324]
      *  Cell distances (variable length * 3 bytes)
      *  -align(4)-
      *  Popcounts A
      *  Popcounts B
      *  Popcounts C
      *  Bits A
      *  Bits B
      *  Bits C
      *  Indexes
      *  -align(4)-
      *  Leaf bundles
      */
    bool getOptVoxel(uint3 offset) {

        uint* optViewUintPtr() { return optView.ptr.as!(uint*); }

        ubyte[] cellSolidFlags() { return optView[4..4100]; }
        ubyte[] cellBitFlags()   { return optView[4100..8196]; }
        uint* cellPopcounts()   { return optView[8196..12288].ptr.as!(uint*); }
        uint offsetPopcountsA()  { return optViewUintPtr()[12288/4] * 4; }
        uint offsetPopcountsB()  { return optViewUintPtr()[12292/4] * 4; }
        uint offsetPopcountsC()  { return optViewUintPtr()[12296/4] * 4; }
        uint offsetBitsA()       { return optViewUintPtr()[12300/4] * 4; }
        uint offsetBitsB()       { return optViewUintPtr()[12304/4] * 4; }
        uint offsetBitsC()       { return optViewUintPtr()[12308/4] * 4; }
        uint offsetIndexes()     { return optViewUintPtr()[12312/4] * 4; }
        uint offsetLeaves()      { return optViewUintPtr()[12316/4] * 4; }
        uint numEntropyBits()    { return optViewUintPtr()[12320/4]; }

        ubyte[] bitsA() { return optView[offsetBitsA()..$]; }
        ubyte[] bitsB() { return optView[offsetBitsB()..$]; }
        ubyte[] bitsC() { return optView[offsetBitsC()..$]; }
        uint* popcountsA() { return optView[offsetPopcountsA()..$].ptr.as!(uint*); }
        uint* popcountsB() { return optView[offsetPopcountsB()..$].ptr.as!(uint*); }
        uint* popcountsC() { return optView[offsetPopcountsC()..$].ptr.as!(uint*); }
        ubyte[] indexes() { return optView[offsetIndexes()..$]; }
        ulong getLeafBundle(uint index) { return optView[offsetLeaves()..$].ptr.as!(ulong*)[index]; }

        if(optView[0].as!M3Flag == M3Flag.AIR) return false;

        // MIXED chunk

        // Check for solid or air cell
        uint cell = getCellOct(offset);

        //writefln("cell = %s", cell);
        if(getBit(4, cell)) return true;        // Solid cell
        if(!getBit(4100, cell)) return false;   // Air cell

        // MIXED cell

        // Level 4
        uint oct4 = getOct(offset, 0b00_0001_0000, 4);
        uint oct3 = getOct(offset, 0b00_0000_1000, 3);
        uint oct2 = getOct(offset, 0b00_0000_0100, 2);
        uint oct1 = getOct(offset, 0b00_0000_0010, 1);
        uint oct0 = getOct(offset, 0b00_0000_0001, 0); // voxel

        //writefln("oct4 = %s, oct3 = %s, oct2 = %s, oct1 = %s, oct0 = %s", oct4, oct3, oct2, oct1, oct0);

        uint a = countSetBits(cellBitFlags(), cellPopcounts(), cell);

        // Bits A
        if(!getBit(offsetBitsA() + a, oct4)) return false; // air

        //writefln("bitsA = %x", optView[offsetBitsA() + a]);
        //

        uint b = countSetBits(bitsA(), popcountsA(), a*8+oct4);

        // Bits B
        if(!getBit(offsetBitsB() + b, oct3)) return false; // air

        uint c = countSetBits(bitsB(), popcountsB(), b*8+oct3);

        // Bits C
        if(!getBit(offsetBitsC() + c, oct2)) return false; // air

        //writefln("bitsC = %x", optView[offsetBitsC() + c]);
        //float f = 4; if(f < 10) return true;

        uint indexPos = countSetBits(bitsC(), popcountsC(), c*8+oct2);
        //writefln("indexPos = %s", indexPos);

        // Index
        uint indexValue = getIndex(indexes(), numEntropyBits(), indexPos);
        //writefln("indexValue = %s", indexValue);

        // Leaves
        ulong leafBundle = getLeafBundle(indexValue);

        //writefln("leafBundle = %016x", leafBundle);

        uint leafBit = oct1*8 + oct0;
        //writefln("leafBit = %s", leafBit);

        return (leafBundle & (1L<<leafBit)) != 0L;
    }
    uint getIndex(ubyte[] indexes, uint numBits, uint index) {
        return bitfieldExtract(indexes, numBits*index, numBits);
    }
    /**
     * uint getImpliedIndex_32bit(const uint bits, const uint oct) {
     *      uint and = 0x7fffffffu >> (31-oct);
     *      return bitCount(bits & and);
     * }
     */
    uint countSetBits(ubyte[] bitsArray, uint* popcounts, uint index) {
        uint a   = index / 32;
        uint b   = index & 31;
        uint and = 0x7fff_ffffu >>> (31-b);

        uint bits = bitsArray.ptr.as!(uint*)[a];
        uint count = a == 0 ? 0 : popcounts[a-1];
        return count + popcnt(bits & and);
    }
    bool getBit(uint start, uint index) {
        uint a = index / 8;
        uint b = index & 7;
        return 0 != (optView[start+a] & (1<<b));
    }
    /// Get cell index (0-32767)
    uint getCellOct(uint3 pos) {
        uint3 p = pos & 0b11_1110_0000;
        /// x =           00_0001_1111 \
        /// y =           11_1110_0000  > cell = 0zzz_zzyy_yyyx_xxxx
        /// z =    0111_1100_0000_0000 /
        auto oct = (p.x>>>5) | p.y | (p.z<<5);
        assert(oct<32768);
        return oct;
    }
    /// Get branch/leaf index (0-7)
    uint getOct(uint3 pos, uint and, uint shift) {
        assert(popcnt(and)==1);
        assert((and>>shift)==1);
        /// For and==1:
        /// x = 0000_0001 \
        /// y = 0000_0001  >  oct = 0000_0zyx
        /// z = 0000_0001 /
        uint3 p = (pos & and)>>shift;
        auto oct = (p << uint3(0, 1, 2)).hadd();
        assert(oct<8);
        return oct;
    }
}