
#line 1 5

// 8 bytes for flags
#define FLAGS_SIZE (8)

bool isSolidRoot(
    const uvec3 upos,
    const uint branchesOffset,
    inout uint voxelsPtr,
    inout Voxel v)
{
    const uint oct = getOctet_1111000000(upos);
    const uint BB  = 512;    // 512 bytes for bits

    const uint BITS_OFFSET = FLAGS_SIZE + 6*4; // octree flag + offset bytes

    const uint uintIndex = (voxelsPtr+BITS_OFFSET)/4 + (oct>>4);
    const uint bitIndex  = oct&15u;
    const uint data      = voxelsIn[uintIndex];
    const uint bits      = data & 0xffffu;

    const bool solid     = !bool(bitfieldExtract(bits, int(bitIndex), 1));

    if(solid) {
        const uint voxelPtr = voxelsPtr+BITS_OFFSET+BB+BB+oct;
        v.size  = CELL_SIZE;
        v.value = GETBYTE(voxelsIn, voxelPtr);
        v.oct   = oct;
    } else {
        const uint popcnt = data >> 16;
        voxelsPtr = branchesOffset +
                    (getImpliedIndex_16bit(bits, bitIndex)+popcnt) * OctreeTwigSize;
    }
    return solid;
}
bool isSolidBranch(
    const float distance,
    const uvec3 upos,
    const uint branchesOffset,
    inout uint voxelsPtr,
    inout Voxel v,
    const uint SZ)
{
    const uint oct   = getOctet_1_n(upos, SZ);
    const uint data  = voxelsIn[voxelsPtr/4];
    const bool solid =
        //distance>(SZ*500) ||
        !bool(bitfieldExtract(data, int(oct), 1));

    if(solid) {
        const uint voxelPtr = voxelsPtr+1+3+oct;
        v.size  = SZ;
        v.value = GETBYTE(voxelsIn, voxelPtr);
    } else {
        const uint bits = data & 0xffu;
        voxelsPtr = branchesOffset +
                    ((data>>8) + getImpliedIndex_8bit(bits, oct)) * OctreeTwigSize;
    }
    return solid;
}
bool isSolidBranch2AboveLeaf(
    const float distance,
    const uvec3 upos,
    const uint bitCounts,
    const uint l2IndexOffset,
    const uint l2TwigsOffset,
    inout uint voxelsPtr,
    inout Voxel v)
{
    const uint oct   = getOctet_0000000100(upos);
    const uint data  = voxelsIn[voxelsPtr/4];
    const bool solid =
        //distance>3000 ||
        !bool(bitfieldExtract(data, int(oct), 1));

    if(solid) {
        const uint voxelPtr = voxelsPtr+1+3+oct;
        v.size  = 4;
        v.value = GETBYTE(voxelsIn, voxelPtr);
    } else {
        const uint bits         = data & 0xffu;
        const uint numIndexBits = (bitCounts >> 8) & 0xffu;
        const uint bitOffset    = ((data>>8) + getImpliedIndex_8bit(bits, oct)) * numIndexBits;
        const uint index        = getBits_voxelsIn(l2IndexOffset, bitOffset, int(numIndexBits));

        voxelsPtr = l2TwigsOffset + index * OctreeTwigSize;
    }
    return solid;
}
bool isSolidBranch1AboveLeaf(
    const float distance,
    const uvec3 upos,
    const uint bitCounts,
    const uint leafIndexOffset,
    const uint leavesOffset,
    inout uint voxelsPtr,
    inout Voxel v)
{
    const uint oct   = getOctet_0000000010(upos);
    const uint data  = voxelsIn[voxelsPtr/4];
    const bool solid =
        //distance>2000 ||
        !bool(bitfieldExtract(data, int(oct), 1));

    if(solid) {
        const uint voxelPtr = voxelsPtr+1+3+oct;
        v.size  = 2;
        v.value = GETBYTE(voxelsIn, voxelPtr);
    } else {
        const uint bits         = data & 0xffu;
        const uint numIndexBits = bitCounts & 0xffu;
        const uint bitOffset    = ((data>>8) + getImpliedIndex_8bit(bits, oct)) * numIndexBits;
        const uint leafIndex    = getBits_voxelsIn(leafIndexOffset, bitOffset, int(numIndexBits));

        voxelsPtr = leavesOffset + leafIndex * OctreeLeafSize;
    }
    return solid;
}
void gavLeaf(const uvec3 upos,
             const uint voxelsPtr,
             inout Voxel v)
{
    const uint oct = getOctet_0000000001(upos);

    v.size  = 1;
    v.value = GETBYTE(voxelsIn, voxelsPtr+oct);
}
/**
 *  Return true if we are inside an air voxel of some size.
 *  Voxel is set accordingly.
 */
bool getAirVoxel(
    const Position pos,
    inout Voxel voxel,
    const float distance,
    const uint voxelsRoot)
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
    const uint offsets = voxelsRoot/4;

    #define l2twigsOffset    voxelsRoot + voxelsIn[offsets+3]
    #define leavesOffset     voxelsRoot + voxelsIn[offsets+4]
    #define l2IndexOffset    voxelsRoot + voxelsIn[offsets+5]
    #define leafIndexOffset  voxelsRoot + voxelsIn[offsets+6]

    #define GETTWIGSOFFSET (voxelsRoot + voxelsIn[offsets+2])
    #define GETBITCOUNTS (voxelsIn[offsets+7])

    const uvec3 upos       = pos.upos;
    const uint twigsOffset = GETTWIGSOFFSET;
    uint voxelsPtr         = voxelsRoot;

    if(isSolidRoot(upos, twigsOffset, voxelsPtr, voxel)) return voxel.value==0;

    if(isSolidBranch(distance, upos, twigsOffset, voxelsPtr, voxel, 32)) return voxel.value==0;

    if(isSolidBranch(distance, upos, twigsOffset, voxelsPtr, voxel, 16)) return voxel.value==0;

    if(isSolidBranch(distance, upos, twigsOffset, voxelsPtr, voxel, 8)) return voxel.value==0;

    const uint bitCounts = GETBITCOUNTS;

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

