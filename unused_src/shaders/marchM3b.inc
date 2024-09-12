
#define UINTOFFSET_CELL_SOLID_FLAGS (4/4)
#define UINTOFFSET_CELL_BIT_FLAGS (4100/4)
#define UINTOFFSET_CELL_POPCOUNTS (8196/4)
#define UINTOFFSET_POPCOUNTSA (12288/4)
#define UINTOFFSET_POPCOUNTSB (12292/4)
#define UINTOFFSET_POPCOUNTSC (12296/4)
#define UINTOFFSET_BITSA (12300/4)
#define UINTOFFSET_BITSB (12304/4)
#define UINTOFFSET_BITSC (12308/4)
#define UINTOFFSET_INDEXES (12312/4)
#define UINTOFFSET_LEAVES (12316/4)
#define BITS_PER_INDEX (12320/4)
#define UINTOFFSET_CELL_DISTANCES (12324/4)

uint offsetBitsA, offsetBitsB, offsetBitsC;
uint offsetPopcountsA, offsetPopcountsB, offsetPopcountsC;
uint offsetIndexes, offsetLeaves, bitsPerIndex;


/// bitsOffset      - uint offset into voxelsIn
/// popcountsOffset - uint offset into voxelsIn
/// index           - bit index
uint countSetBits(uint bitsUintOffset, uint popcountsUintOffset, uint index) {
    uint a   = index / 32;
    uint b   = index & 31;
    uint and = 0x7fffffffu >> (31-b);

    uint bits = voxelsIn[bitsUintOffset + a];
    uint count = a == 0 ? 0 : voxelsIn[popcountsUintOffset + a - 1];
    return count + bitCount(bits & and);
}
uint countUnsetBits(uint bitsUintOffset, uint popcountsUintOffset, uint index) {
    return index - countSetBits(bitsUintOffset, popcountsUintOffset, index);
}
// indexesOffset - byte offset into voxelsIn
// numBits       - num bits per index
// index         - index number
uint getIndex(uint indexesByteOffset, uint numBits, uint index) {
    return getBits(indexesByteOffset, numBits*index, int(numBits));
}

///
/// Return true if we are inside an air voxel of some size.
/// Voxel is set accordingly.
///
bool getAirVoxel(Position pos, inout Voxel voxel, float distance, uint voxels) {
    uvec3 upos = pos.upos;

    // [00004] Cell solid flags (4096 bytes) 1 = solid cell, 0 = air or mixed
    // [04100] Cell bit flags   (4096 bytes) 0 = air,        1 = mixed

    uint cellOct = getOctet_1111100000(upos);   // from 0 to 32767

    //bool isSolidBlock = getBit(voxels + UINTOFFSET_CELL_SOLID_FLAGS, cellOct);
    bool isSolidAir   = !getBit(voxels + UINTOFFSET_CELL_BIT_FLAGS, cellOct);

    if(isSolidAir) {
        // Solid air cell
        voxel.size  = 32;
        voxel.value = 0;
        voxel.oct   = cellOct;
        return true;
    } else if(getBit(voxels + UINTOFFSET_CELL_SOLID_FLAGS, cellOct)) {
        // Solid block cell
        voxel.size  = 32;
        voxel.value = 1;
        voxel.oct   = cellOct;
        return false;
    }

    //----------------------------------------------------------------------------------------------
    // MIXED cell
    //----------------------------------------------------------------------------------------------
    uint oct4 = getOctet_0000010000(upos);
    uint a = countSetBits(voxels+UINTOFFSET_CELL_BIT_FLAGS, voxels+UINTOFFSET_CELL_POPCOUNTS, cellOct);

    if(!getBit(voxels + offsetBitsA, oct4 + a*8)) {
        // air
        voxel.size  = 16;
        voxel.value = 0;
        return true;
    }

    //----------------------------------------------------------------------------------------------
    // Down to 8
    //----------------------------------------------------------------------------------------------
    uint oct3 = getOctet_0000001000(upos);
    uint b = countSetBits(voxels + offsetBitsA, voxels + offsetPopcountsA, a*8+oct4);

    // // Bits B
    if(!getBit(voxels + offsetBitsB, oct3 + b*8)) {
        // air
        voxel.size  = 8;
        voxel.value = 0;
        return true;
    }

    //----------------------------------------------------------------------------------------------
    // Down to 4
    //----------------------------------------------------------------------------------------------
    uint oct2 = getOctet_0000000100(upos);
    uint c = countSetBits(voxels + offsetBitsB, voxels + offsetPopcountsB, b*8+oct3);

    if(!getBit(voxels + offsetBitsC, oct2 + c*8)) {
        // air
        voxel.size  = 4;
        voxel.value = 0;
        return true;
    }

    //----------------------------------------------------------------------------------------------
    // Down to Leaf Bundles
    //----------------------------------------------------------------------------------------------
    uint indexPos = countSetBits(voxels + offsetBitsC, voxels + offsetPopcountsC, c*8+oct2);
    uint indexValue = getIndex((voxels + offsetIndexes)*4, bitsPerIndex, indexPos);

    voxel.size = 1;

    uint oct1 = getOctet_0000000010(upos);
    uint oct0 = getOctet_0000000001(upos);
    uint leafBit = oct1*8 + oct0;

    uint bundle = leafBit < 32 ? voxelsIn[voxels + offsetLeaves + indexValue*2 + 0]
                               : voxelsIn[voxels + offsetLeaves + indexValue*2 + 1];

    leafBit = leafBit >= 32 ? leafBit-32 : leafBit;

    bool isAir = (bundle & (1<<leafBit)) == 0;

    voxel.value = isAir ? 0 : 1;

    return isAir;
}
