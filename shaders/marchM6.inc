
uint getXYBits(uint cellVoxels, uint index) {
    return 0;
}

///
/// Return true if we hit something.
/// Voxel is set accordingly.
///
bool marchCell(const Ray ray, inout Position pos, inout Voxel voxel, const uint chunkVoxels, const uint cell) {

    uint offset = get3Bytes(CELL_OFFSETS, cell);

    if(offset==0xffffff) {
        // The cell is SOLID
        voxel.size  = 32;
        voxel.value = 1;
        return true;
    }

    // The cell is not AIR or SOLID

    uint numUniqXYBits = getNumUniqXYBits(chunkVoxels);
    uint numUniqZBits  = getNumUniqZBits(chunkVoxels);
    uint numUniqCounts = getNumUniqCounts(chunkVoxels);

    uint cellVoxels = chunkVoxels + offset + 25605 + numUniqXYBits + numUniqZBits + ((numUniqCounts*10 + 31) / 32);

    uvec3 upos = pos.upos;
    uint x     = upos.x & 31;
    uint y     = (upos.y >> 5) & 31;
    uint z     = (upos.z >> 10) & 31;

    uint xRanks = voxelsIn[cellVoxels];
    uint yRanks = voxelsIn[cellVoxels + 1];

    // if(0 == (xRanks & x)) {
    //     // air
    //     voxel.size  = 1;
    //     voxel.value = 1;
    //     return true;
    // }



    //bool bit = 0 != (xyBits[y] & (1<<x));

    //float d = getMinDistToEdge(ray, pos, CELL_SIZE);


    // updatePositionWithinCell(pos, vec3);



    return false;
}

