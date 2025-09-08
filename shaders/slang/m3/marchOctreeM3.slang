#language slang 2026
implementing m3;

import blockie;

///
/// Return true if we are inside an air voxel of some size.
/// Voxel is set accordingly.
///
public bool getAirVoxel(const VoxelsBuffer voxelsIn, const Position pos, inout Voxel voxel, float distance, uint voxels) {
    uint3 upos = pos.upos;

    uint branch;

    // Out: L4branch
    if(isSolidCell(voxelsIn, upos, voxels, branch, voxel)) return voxel.value==0;

    // In:  L4branch, octLevel=3, size=16, and=0b00_0000_1000
    // Out: L3branch
    if(isSolidBranch(voxelsIn, distance, upos, voxels, branch, voxel, 3, 16)) return voxel.value==0;

    // In:  L3branch, octLevel=2, size=8, and=0b00_0000_0100
    // Out: L2branch
    if(isSolidBranch(voxelsIn, distance, upos, voxels, branch, voxel, 2, 8)) return voxel.value==0;

    // In: L2branch, octLevel=1, size=4, and=0b00_0000_0010
    leaf(voxelsIn, distance, upos, voxels, branch, voxel);

    return voxel.value==0;
}

bool isSolidCell(const VoxelsBuffer voxelsIn, uint3 upos, uint voxels, inout uint outL4Branch, inout Voxel v) {
    uint cellOct = getOctet_1111100000(upos);
    uint cell    = voxelsIn[voxels+2+cellOct];

    uint bits  = cell & 0xffu;
    uint l4oct = getOctet_0000010000(upos);

    bool air   = (bitfieldExtract(bits, int(l4oct), 1)==0);
    bool solid = air || (cell == 0xffffffff);

    if(solid) {
        // Solid air or solid stuff
        v.size  = bits==0 ? 32 : 16;
        v.value = uint(!air);
        v.oct   = cellOct;
    } else {
        // Drill down

        // Read L4 branch
        uint offset = (cell >> 8) + getImpliedIndex_8bit(bits, l4oct);
        outL4Branch = voxelsIn[voxels+offset];
    }
    return solid;
}
bool isSolidBranch(
    const VoxelsBuffer voxelsIn,
    float distance,
    uint3 upos,
    uint voxels,
    inout uint branch,  // branch value in/out
    inout Voxel v,
    int octLevel,
    uint size)
{
    uint oct  = getOctet_n_1(upos, octLevel);
    uint bits = branch & 0xffu;

    bool air   = (bitfieldExtract(bits, int(oct), 1)==0);
    bool solid = air || (branch == 0xffffffff);

    if(solid) {
        // Solid air or solid stuff
        v.size  = bits==0xff ? size : size/2;
        v.value = uint(!air);
        //v.oct   = oct;
    } else {
        // Drill down

        // Read next branch
        uint offset = (branch >> 8) + getImpliedIndex_8bit(bits, oct);
        branch = voxelsIn[voxels+offset];
    }
    return solid;
}
void leaf(
    const VoxelsBuffer voxelsIn,
    float distance,
    uint3 upos,
    uint voxels,
    uint branch,  // L2branch in
    inout Voxel v)
{
    uint l1oct = getOctet_0000000010(upos);
    uint bits = branch & 0xffu;

    bool air   = (bitfieldExtract(bits, int(l1oct), 1)==0);
    bool solid = air || (branch == 0xffffffff);

     if(solid) {
        // Solid air or solid stuff
        v.size  = bits==0xff ? 4 : 2;
        v.value = uint(!air);
        //v.oct   = l1oct;
    } else {
        // leaf
        uint offset     = (branch >> 8);
        uint byteOffset = getImpliedIndex_8bit(bits, l1oct);
        uint leaf       = getByte(voxelsIn, 0, (voxels+offset)*4 + byteOffset);

        uint l0oct = getOctet_0000000001(upos);

        v.size  = 1;
        v.value = bitfieldExtract(leaf, int(l0oct), 1);
    }
}


