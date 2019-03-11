
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


uint bitsRequiredToEncode(uint value) {
    return value<3 ? 1 : findMSB(value-1)+1;
}

/// Assumes numBits is between 1 and 32.
uint getBits(uint byteIndex, uint bitOffset, int numBits) {
    byteIndex += bitOffset/8;
    bitOffset &= 7u;

    uint uintIndex = byteIndex/4;
    uint uintRem   = byteIndex&3u;

    int bitpos     = int(bitOffset + (uintRem*8));
    int numBits2   = max(0, numBits - (32-bitpos));
    numBits -= numBits2;
    uint result = bitfieldExtract(voxelsIn[uintIndex], bitpos, numBits);
    uint add = numBits2 == 0 ? 0 :
                (bitfieldExtract(voxelsIn[uintIndex+1], 0, numBits2) << numBits);
    return result + add;
}

uint getImpliedIndex(uint bits, uint oct) {
    uint and = 0x7fffffffu >> (31-oct);
    return bitCount(bits & and);
}
/// Assumes offsets are in uints
uint getIndex(uint oct, uint voxels, uint popcountsOffset, uint bitsOffset) {
    uint popcount = oct<32 ? 0
        : voxelsIn[voxels + popcountsOffset + (oct/32)-1];

    return getImpliedIndex(voxelsIn[voxels + bitsOffset + oct/32], oct&31u)
            + popcount;
}
/// Get 7 bit cell octet (0-2097151)
/// 11_1111_1000 -> z_zzzz_zzyy_yyyy_yxxx_xxxx
uint getCellOct(uvec3 upos) {
    uvec3 a = bitfieldExtract(upos, 3, 7); // offset 3, 7 bits
    uvec3 c = a << uvec3(0,7,14);
    return c.x + c.y + c.z;
}
uint getOctets(uvec3 upos, int bitOffset, int numBits) {
    uvec3 a = bitfieldExtract(upos, bitOffset, numBits);
    uvec3 c = a << uvec3(0,numBits,numBits+numBits);
    return c.x + c.y + c.z;
}
/// Get 1 bit octet index (0-7)
/// if shr==5 (and==1<<shr):
/// x = 0_0010_0000 \
/// y = 0_0010_0000  >  oct = 00000zyx
/// z = 0_0010_0000 /
uint getOctet(uvec3 upos, int bitOffset) {
	uvec3 a = bitfieldExtract(upos, bitOffset, 1);
    uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
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
    uint cellOct = getCellOct(upos);

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

    uint branchOct = getOctet(upos, 2);
    uint index100  = 8*getIndex(cellOct, voxels, L7POPCOUNTS_OFFSET/4, BITS_L7/4);

    if(isBitZero(index100 + branchOct, voxels + L100_BITS_OFFSET/4)) {
        return 4;
    }

    uint leafOct     = getOctet(upos, 1);
    uint voxelOct    = getOctet(upos, 0);
    uint index10     = getIndex(index100 + branchOct, voxels, L100PopcountsOffset, L100_BITS_OFFSET/4);
    uint ptrBitIndex = (voxels+branchPtrsOffset)*32 + index10 * bitsPerBranch;
    uint branchPtr   = getBits(0, ptrBitIndex, int(bitsPerBranch));

    uint i = voxelsIn[voxels + uniqBranchesOffset + branchPtr*2 + leafOct/4];
    uint r = (leafOct&3u) * 8;
    uint b = (i >> r) & 0xffu;

    return b==0 ? 2 : uint((b & (1u<<voxelOct)) == 0);
}
