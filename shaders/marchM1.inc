
#line 1 5

// 8 bytes for flags
#define FLAGS_SIZE (8)

bool isSolidRoot(
    uvec3 upos,
    uint branchesOffset,
    inout uint voxelsPtr,
    inout Voxel v)
{
    uint oct = getOctet_1111000000(upos);
    uint BB  = 512;    // 512 bytes for bits

    uint BITS_OFFSET = FLAGS_SIZE + 6*4; // octree flag + offset bytes

    uint uintIndex = (voxelsPtr+BITS_OFFSET)/4 + (oct>>4);
    uint bitIndex  = oct&15u;
    uint data      = voxelsIn[uintIndex];
    uint bits      = data & 0xffffu;

    bool solid     = !bool(bitfieldExtract(bits, int(bitIndex), 1));

    if(solid) {
        uint voxelPtr = voxelsPtr+BITS_OFFSET+BB+BB+oct;
        v.size  = CELL_SIZE;
        v.value = GETBYTE(voxelsIn, voxelPtr);
        v.oct   = oct;
    } else {
        uint popcnt = data >> 16;
        voxelsPtr = branchesOffset +
                    (getImpliedIndex_16bit(bits, bitIndex)+popcnt) * OctreeTwigSize;
    }
    return solid;
}
bool isSolidBranch(
    float distance,
    uvec3 upos,
    uint branchesOffset,
    inout uint voxelsPtr,
    inout Voxel v,
    uint SZ)
{
    uint oct   = getOctet_1_and(upos, SZ);
    uint data  = voxelsIn[voxelsPtr/4];
    bool solid =
        //distance>(SZ*500) ||
        !bool(bitfieldExtract(data, int(oct), 1));

    if(solid) {
        uint voxelPtr = voxelsPtr+1+3+oct;
        v.size  = SZ;
        v.value = GETBYTE(voxelsIn, voxelPtr);
    } else {
        uint bits = data & 0xffu;
        voxelsPtr = branchesOffset +
                    ((data>>8) + getImpliedIndex_8bit(bits, oct)) * OctreeTwigSize;
    }
    return solid;
}
bool isSolidBranch2AboveLeaf(
    float distance,
    uvec3 upos,
    uint bitCounts,
    uint l2IndexOffset,
    uint l2TwigsOffset,
    inout uint voxelsPtr,
    inout Voxel v)
{
    uint oct   = getOctet_0000000100(upos);
    uint data  = voxelsIn[voxelsPtr/4];
    bool solid =
        //distance>3000 ||
        !bool(bitfieldExtract(data, int(oct), 1));

    if(solid) {
        uint voxelPtr = voxelsPtr+1+3+oct;
        v.size  = 4;
        v.value = GETBYTE(voxelsIn, voxelPtr);
    } else {
        uint bits         = data & 0xffu;
        uint numIndexBits = (bitCounts >> 8) & 0xffu;
        uint bitOffset    = ((data>>8) + getImpliedIndex_8bit(bits, oct)) * numIndexBits;
        uint index        = getBits_voxelsIn(l2IndexOffset, bitOffset, int(numIndexBits));

        voxelsPtr = l2TwigsOffset + index * OctreeTwigSize;
    }
    return solid;
}
bool isSolidBranch1AboveLeaf(
    float distance,
    uvec3 upos,
    uint bitCounts,
    uint leafIndexOffset,
    uint leavesOffset,
    inout uint voxelsPtr,
    inout Voxel v)
{
    uint oct   = getOctet_0000000010(upos);
    uint data  = voxelsIn[voxelsPtr/4];
    bool solid =
        //distance>2000 ||
        !bool(bitfieldExtract(data, int(oct), 1));

    if(solid) {
        uint voxelPtr = voxelsPtr+1+3+oct;
        v.size  = 2;
        v.value = GETBYTE(voxelsIn, voxelPtr);
    } else {
        uint bits         = data & 0xffu;
        uint numIndexBits = bitCounts & 0xffu;
        uint bitOffset    = ((data>>8) + getImpliedIndex_8bit(bits, oct)) * numIndexBits;
        uint leafIndex    = getBits_voxelsIn(leafIndexOffset, bitOffset, int(numIndexBits));

        voxelsPtr = leavesOffset + leafIndex * OctreeLeafSize;
    }
    return solid;
}
void gavLeaf(uvec3 upos,
             uint voxelsPtr,
             inout Voxel v)
{
    uint oct = getOctet_0000000001(upos);

    v.size  = 1;
    v.value = GETBYTE(voxelsIn, voxelsPtr+oct);
}
/**
 *  Return true if we are inside an air voxel of some size.
 *  Voxel is set accordingly.
 */
bool getAirVoxel(
    Position pos,
    inout Voxel voxel,
    float distance,
    uint voxelsRoot)
{
/*
    voxelsIn[voxelsRoot/4 + 0] = flags (8 bytes)
    voxelsIn[voxelsRoot/4 + 2] = twigsOffset;
    voxelsIn[voxelsRoot/4 + 3] = l2TwigsOffset;
    voxelsIn[voxelsRoot/4 + 4] = leavesOffset;
    voxelsIn[voxelsRoot/4 + 5] = l2IndexOffset;
    voxelsIn[voxelsRoot/4 + 6] = leafIndexOffset;
    voxelsIn[voxelsRoot/4 + 7] = (leafEncodeBits | (l2EncodeBits<<8));
*/
    uint offsets = voxelsRoot/4;

    #define l2twigsOffset    voxelsRoot + voxelsIn[offsets+3]
    #define leavesOffset     voxelsRoot + voxelsIn[offsets+4]
    #define l2IndexOffset    voxelsRoot + voxelsIn[offsets+5]
    #define leafIndexOffset  voxelsRoot + voxelsIn[offsets+6]

    #define GETTWIGSOFFSET (voxelsRoot + voxelsIn[offsets+2])
    #define GETBITCOUNTS (voxelsIn[offsets+7])

    uvec3 upos       = pos.upos;
    uint twigsOffset = GETTWIGSOFFSET;
    uint voxelsPtr   = voxelsRoot;

    if(isSolidRoot(upos, twigsOffset, voxelsPtr, voxel)) return voxel.value==0;

    if(isSolidBranch(distance, upos, twigsOffset, voxelsPtr, voxel, 32)) return voxel.value==0;

    if(isSolidBranch(distance, upos, twigsOffset, voxelsPtr, voxel, 16)) return voxel.value==0;

    if(isSolidBranch(distance, upos, twigsOffset, voxelsPtr, voxel, 8)) return voxel.value==0;

    uint bitCounts = GETBITCOUNTS;

    if(isSolidBranch2AboveLeaf(
        distance,
        upos,
        bitCounts,
        l2IndexOffset,
        l2twigsOffset,
        voxelsPtr,
        voxel)) return voxel.value==0;

    if(isSolidBranch1AboveLeaf(
        distance,
        upos,
        bitCounts,
        leafIndexOffset,
        leavesOffset,
        voxelsPtr,
        voxel)) return voxel.value==0;

    gavLeaf(upos, voxelsPtr, voxel);

    return voxel.value==0;
}

