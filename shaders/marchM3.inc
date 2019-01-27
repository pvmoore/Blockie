

uint getImpliedIndex(uint bits, uint oct) {
    uint and = 0x7f >> (7-oct);
    return bitCount(bits & and);
}
/// Get 5 bit cell octet index (0-32767)
// 11_1110_0000 -> 0zzz_zzyy_yyyx_xxxx
uint getCellOctet(uvec3 upos) {
    uvec3 a = bitfieldExtract(upos, 5, 5);
    uvec3 c = a << uvec3(0,5,10);
    return c.x + c.y + c.z;
}
/// Get 1 bit octet index (0-7)
/// if shr==5 (and==1<<shr):
/// x = 0_0010_0000 \
/// y = 0_0010_0000  >  oct = 00000zyx
/// z = 0_0010_0000 /
uint getOctet(uvec3 upos, int shr) {
	uvec3 a = bitfieldExtract(upos, shr, 1);
    uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
}

bool isSolidCell(uvec3 upos, uint voxels, inout uint outL4Branch, inout Voxel v) {
    uint cellOct = getCellOctet(upos);
    uint cell    = voxelsIn[voxels+1+cellOct];

    uint bits  = cell & 0xffu;
    uint l4oct = getOctet(upos, 4);

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
        uint offset = (cell >> 8) + getImpliedIndex(bits, l4oct);
        outL4Branch = voxelsIn[voxels+offset];
    }
    return solid;
}
bool isSolidBranch(
    float distance,
    uvec3 upos,
    uint voxels,
    inout uint branch,  // branch value in/out
    inout Voxel v,
    int octLevel,
    uint size)
{
    uint oct  = getOctet(upos, octLevel);
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
        uint offset = (branch >> 8) + getImpliedIndex(bits, oct);
        branch = voxelsIn[voxels+offset];
    }
    return solid;
}
void leaf(
    float distance,
    uvec3 upos,
    uint voxels,
    uint branch,  // L2branch in
    inout Voxel v)
{
    uint l1oct = getOctet(upos, 1);
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
        uint byteOffset = getImpliedIndex(bits, l1oct);
        uint leaf       = GETBYTE(voxelsIn, (voxels+offset)*4 + byteOffset);

        uint l0oct = getOctet(upos, 0);

        v.size  = 1;
        v.value = bitfieldExtract(leaf, int(l0oct), 1);
    }
}

///
/// Return true if we are inside an air voxel of some size.
/// Voxel is set accordingly.
///
bool getAirVoxel(Position pos, inout Voxel voxel, float distance, uint voxels) {
    uvec3 upos = pos.upos;

    uint branch;

    // Out: L4branch
    if(isSolidCell(upos, voxels, branch, voxel)) return voxel.value==0;

    // In:  L4branch, octLevel=3, size=16, and=0b00_0000_1000
    // Out: L3branch
    if(isSolidBranch(distance, upos, voxels, branch, voxel, 3, 16)) return voxel.value==0;

    // In:  L3branch, octLevel=2, size=8, and=0b00_0000_0100
    // Out: L2branch
    if(isSolidBranch(distance, upos, voxels, branch, voxel, 2, 8)) return voxel.value==0;

    // In: L2branch, octLevel=1, size=4, and=0b00_0000_0010
    leaf(distance, upos, voxels, branch, voxel);

    return voxel.value==0;
}
