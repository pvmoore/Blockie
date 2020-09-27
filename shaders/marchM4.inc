
#define L7POPCOUNTS_OFFSET          (8)
#define L100BITS_LEN_OFFSET         (561748)
#define NUM_UNIQ_BRANCHES_OFFSET    (561752)
#define L100_BITS_OFFSET            (561756)

#define BITS_OFFSET      (8+262144+262144)

#define BITS_L1          (BITS_OFFSET)
#define BITS_L2          (BITS_OFFSET+4)
#define BITS_L3          (BITS_OFFSET+12)
#define BITS_L4          (BITS_OFFSET+76)
#define BITS_L5          (BITS_OFFSET+588)
#define BITS_L6          (BITS_OFFSET+4684)
#define BITS_L7          (8+262144)


// Set when chunk changes
uint L100_BITS_LEN;
uint NUM_UNIQ_BRANCHES;

uint L100PopcountsOffset;
uint uniqBranchesOffset;
uint cellDistancesOffset;
uint branchPtrsOffset;
uint bitsPerBranch;


/// Assumes offsets are in uints
uint getIndex(uint oct, uint voxels, uint popcountsOffset, uint bitsOffset) {
    uint popcount = oct<32 ? 0
        : voxelsIn[voxels + popcountsOffset + (oct/32)-1];

    return getImpliedIndex_32bit(voxelsIn[voxels + bitsOffset + oct/32], oct&31u) + popcount;
}


/// Assumes offsets are in uints
//bool isBitSet(uint bit, uint offset) {
//    uint b = voxelsIn[offset + bit/32];
//    return (b & (1u<<(bit&31u))) != 0;
//}
/// Assumes offsets are in uints
bool isBitZero(uint bit, uint offset) {
    uint b = voxelsIn[offset + bit/32];
    return (b & (1u<<(bit&31u))) == 0;
}
bool isAirCell(uint cell, uint voxels) {
    return isBitZero(cell, voxels + BITS_L7/4);
}
bool isAir(inout uvec3 p, inout uint size, uint level, uint offset) {
    p >>= 1;
    uint bit = p.x | (p.y<<level) | (p.z<<(level+level));
    bool b   = isBitZero(bit, offset);
    size <<= uint(b);
    return b;
}
///
/// Return air voxel air size (0 = we have hit something)
///
uint getAirVoxel(Position pos, uint voxels) {
    uvec3 upos   = pos.upos;
    uint cellOct = getOctet_1111111000(upos);

//    if(isBitZero(getOctets(upos, 9, 1), voxels + BITS_L1/4)) return 512;
//    if(isBitZero(getOctets(upos, 8, 2), voxels + BITS_L2/4)) return 256;
//    if(isBitZero(getOctets(upos, 7, 3), voxels + BITS_L3/4)) return 128;
//    if(isBitZero(getOctets(upos, 6, 4), voxels + BITS_L4/4)) return 64;
//    if(isBitZero(getOctets(upos, 5, 5), voxels + BITS_L5/4)) return 32;

    //if(isAirCell(cellOct, voxels)) return 8;

    if(isAirCell(cellOct, voxels)) {
        /// Scan higher level octets to get the volume of air

        uvec3 p   = uvec3(cellOct, cellOct, cellOct) >> uvec3(0, 7, 14) & 127u;
        uint size = 8;

        bool r = isAir(p, size, 6, voxels+BITS_L6/4)
              //&& isAir(p, size, 5, voxels+BITS_L5/4)
              //&& isAir(p, size, 4, voxels+BITS_L4/4)
              //&& isAir(p, size, 3, voxels+BITS_L3/4)
              //&& isAir(p, size, 2, voxels+BITS_L2/4)
            //&& isAir(p, size, 1, voxels+BITS_L1/4)
                ;

        return size;
    }

    uint branchOct = getOctet_0000000100(upos);
    uint index100  = 8*getIndex(cellOct, voxels, L7POPCOUNTS_OFFSET/4, BITS_L7/4);

    if(isBitZero(index100 + branchOct, voxels + L100_BITS_OFFSET/4)) {
        return 4;
    }

    uint leafOct     = getOctet_0000000010(upos);
    uint voxelOct    = getOctet_0000000001(upos);
    uint index10     = getIndex(index100 + branchOct, voxels, L100PopcountsOffset, L100_BITS_OFFSET/4);
    uint ptrBitIndex = (voxels+branchPtrsOffset)*32 + index10 * bitsPerBranch;
    uint branchPtr   = getBits_voxelsIn(0, ptrBitIndex, int(bitsPerBranch));

    uint i = voxelsIn[voxels + uniqBranchesOffset + branchPtr*2 + leafOct/4];
    uint r = (leafOct&3u) * 8;
    uint b = (i >> r) & 0xffu;

    return b==0 ? 2 : uint((b & (1u<<voxelOct)) == 0);
}
