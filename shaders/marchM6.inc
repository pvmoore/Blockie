
#define NUM_UNIQ_OFFSETS            (2+1024+24576)
#define UNIQ_BITS_AND_COUNTS_OFFSET (25605)

uint fetchNumUniqXYBits(uint chunkVoxels) { return voxelsIn[chunkVoxels + NUM_UNIQ_OFFSETS]; }
uint fetchNumUniqZBits(uint chunkVoxels)  { return voxelsIn[chunkVoxels + NUM_UNIQ_OFFSETS+1]; }
uint fetchNumUniqCounts(uint chunkVoxels) { return voxelsIn[chunkVoxels + NUM_UNIQ_OFFSETS+2]; }

uint calculateC0Uint(uint chunkVoxels, uint cellOffset, uint numUniqXYBits, uint numUniqZBits, uint numUniqCounts) {
    return chunkVoxels + UNIQ_BITS_AND_COUNTS_OFFSET +
                      cellOffset +
                      numUniqXYBits + numUniqZBits + countUints(numUniqCounts*10);
}

uint fetchUniqXYBitsValue(uint chunkVoxels, uint i) {
    return voxelsIn[chunkVoxels + UNIQ_BITS_AND_COUNTS_OFFSET + i];
}
uint fetchUniqXYCountsValue(uint chunkVoxels, uint numUniqXYBits, uint numUniqZBits, uint i) {
    uint uintOffset = chunkVoxels + UNIQ_BITS_AND_COUNTS_OFFSET + numUniqXYBits + numUniqZBits;
    return getBits_voxelsIn(uintOffset*4, i*10, 10);
}
uint fetchUniqZBitsValue(uint chunkVoxels, uint numUniqXYBits, uint i) {
    return voxelsIn[chunkVoxels + UNIQ_BITS_AND_COUNTS_OFFSET + numUniqXYBits + i];
}

uint getXYBits(uint chunkVoxels, uint C1, uint bitsPerXYBits, uint y) {
    // Get the unique index
    uint i = getBits_voxelsIn(C1, y*bitsPerXYBits, int(bitsPerXYBits));

    // Now lookup the unique xyBits value
    return fetchUniqXYBitsValue(chunkVoxels, i);
}
uint getXYCount(uint chunkVoxels, uint C2, uint bitsPerXYCount, uint numUniqXYBits, uint numUniqZBits, uint y) {
    // Get the unique index
    uint i = getBits_voxelsIn(C2, y*bitsPerXYCount, int(bitsPerXYCount));

    // Now lookup the unique xyCounts value
    return fetchUniqXYCountsValue(chunkVoxels, numUniqXYBits, numUniqZBits, i);
}
uint getZBits(uint chunkVoxels, uint C3, uint numUniqXYBits, uint bitsPerZValues, uint xyBits, uint xyCount, uint x) {
    // Get index of z row
    uint i = xyCount + getImpliedIndex_32bit(xyBits, x);

    // read encoded value at index i
    uint j = getBits_voxelsIn(C3, i*bitsPerZValues, int(bitsPerZValues));

    // Get the z row
    return fetchUniqZBitsValue(chunkVoxels, numUniqXYBits, j);
}



///
/// Return distance to move.
/// If voxel.value != 0 then we hit something
///
float marchCell(const Ray ray, const Position pos, inout Voxel voxel, const uint chunkVoxels, const uint cell, const float inDistance) {

    uint offset = get3Bytes(CELL_OFFSETS, cell);

    if(offset==0xffffff) {
        // The cell is SOLID
        voxel.size  = 32;
        voxel.value = 1;
        return 0;
    }

    // The cell is not AIR or SOLID

    uint numUniqXYBits = fetchNumUniqXYBits(chunkVoxels);
    uint numUniqZBits  = fetchNumUniqZBits(chunkVoxels);
    uint numUniqCounts = fetchNumUniqCounts(chunkVoxels);

    uint C0 = calculateC0Uint(chunkVoxels, offset, numUniqXYBits, numUniqZBits, numUniqCounts);



    // Check for a large volume of air either in the x or the y direction
    //       y
    //       |
    //       +------++-----+
    //      /|     //|    /|
    //     / |    //||   / |
    //    /  |   // ||  /  |
    //   +------++-----+   |
    //   |   |  ||  || |   |
    //   |   +--||--++-|---+ -->x
    //   |  /   || //  |  /
    //   | /    ||//   | /
    //   |/     ||/    |/
    //   +------++-----+
    //  /
    // z
    //          y
    //          |
    //          +--------------+
    //         /|             /|
    //        / |            / |
    //       /  |           /  |
    //      /   +----------/---+
    //     /   /+---------/---/+
    //    /   //|        /   //|
    //   +--------------+   // |
    //   |  //  |       |  //  |
    //   | //   +-------|-//---+ -->x
    //   |//   /        |//   /
    //   +--------------+/   /
    //   +--------------+   /
    //   |  /           |  /
    //   | /            | /
    //   |/             |/
    //   +--------------+
    //  /
    // z
    //

    uint xRanks = voxelsIn[C0];

    // if(0 == (xRanks & (1<<x))) {
    //     // The whole xy slice is air (vertical)
    //     // We can possible expand this air volume by checking surrounding x values

    //     uvec3 airVolume = uvec3(1, min(y+1, 32-y), min(z+1, 32-z));

    //     return getMinDistToEdge(ray, pos, airVolume);
    // }

    uint yRanks = voxelsIn[C0 + 1];
    // if(0 == (yRanks & (1<<y))) {
    //     // The whole xy slice is air (horizontal)
    //     // We can possible expand this air volume by checking surrounding y values

    //     uvec3 airVolume = uvec3(min(x+1, 32-x), 1, min(z+1, 32-z));

    //     return getMinDistToEdge(ray, pos, airVolume);
    // }



    // If we get here then we need to march the current voxel

    // uint xRanks
    // uint yRanks
    // 4-bits bitsPerXYBits (BPXY-1)
    // 4-bits bitsPerZValues (BPZ-1)
    // 4-bits bitsPerCount (BPC-1)
    // 4-bits _reserved
    uint temp = voxelsIn[C0 + 2];
    uint bitsPerXYBits  = (temp & 15u) + 1;
    uint bitsPerZValues = ((temp >> 4) & 15u) + 1;
    uint bitsPerCount   = ((temp>>8) & 15u) + 1;

    C0 *= 4;    // cell mixed data offset

    uint C1 = C0 + 10;                              // xyBits offset
    uint C2 = C1 + countBytes(bitsPerXYBits*32);    // xyCounts offset
    uint C3 = C2 + countBytes(bitsPerCount*32);     // zBits offset

    // Start marching ...

    uvec3 upos = pos.upos;
    uint x     = upos.x & 31u;
    uint y     = upos.y & 31u;
    uint z     = upos.z & 31u;

    uvec3 u = upos & 31u;

    float maxDistance = getMinDistToEdge(ray, pos, min(u+1, 32-u));
    float distance = 0;
    Position p = pos;

    while(distance < maxDistance) {
        float dist;

        upos  = p.upos;
        x     = upos.x & 31u;
        y     = upos.y & 31u;
        z     = upos.z & 31u;

        uint xyBits = getXYBits(chunkVoxels, C1, bitsPerXYBits, y);

        bool zRowIsAir = 0 == (xyBits & (1<<x));

        if(zRowIsAir) {
            dist = getMinDistToEdge(ray, p, uvec3(1,1, min(z+1, 32-z)));
        } else {
            // Check zrow

            uint xyCount = getXYCount(chunkVoxels, C2, bitsPerCount, numUniqXYBits, numUniqZBits, y);
            uint zBits   = getZBits(chunkVoxels, C3, numUniqXYBits, bitsPerZValues, xyBits, xyCount, x);
            bool zBit    = 0 != (zBits & (1<<z));

            if(zBit) {
                voxel.value = 1;
                voxel.size  = 1;
                return distance;
            }

            dist = getMinDistToEdge(ray, p, 1);
        }

        skipLOD(inDistance, dist);
        distance += dist;

        updatePositionWithinCell(p, ray.direction*dist);
    }

    return distance;
}
