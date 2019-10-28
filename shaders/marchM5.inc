

uint getImpliedIndex(uint bits, uint oct) {
    uint and = 0x7fu >> (7-oct);
    return bitCount(bits & and);
}
uint getImpliedIndex2(uint bits, uint bits2, uint oct) {
    return oct<32 ?
        bitCount(bits & (0x7fffffffu >> (31-oct))) :
        bitCount(bits) + bitCount(bits2 & (0x7fffffffu >> (63-oct)));
}
/// Get 4 bit cell octet index (0-4095)
// 11_1100_0000 -> zzzz_yyyyxxxx
uint oct_11_1100_0000(uvec3 upos) {
    uvec3 a = bitfieldExtract(upos, 6, 4);
    uvec3 c = a << uvec3(0,4,8);
    return c.x + c.y + c.z;
}
/// Get 2 bit cell octet index (0-63)
// 00_0011_0000 -> zzyyxx
uint oct_00_0011_0000(uvec3 upos) {
    uvec3 a = bitfieldExtract(upos, 4, 2);
    uvec3 c = a << uvec3(0,2,4);
    return c.x + c.y + c.z;
}
/// Get 2 bit cell octet index (0-63)
// 00_0000_1100 -> zzyyxx
uint oct_00_0000_1100(uvec3 upos) {
    uvec3 a = bitfieldExtract(upos, 2, 2);
    uvec3 c = a << uvec3(0,2,4);
    return c.x + c.y + c.z;
}
/// Get 2 bit cell octet index (0-7)
// 00_0000_0010 -> zyx
uint oct_00_0000_0010(uvec3 upos) {
    uvec3 a = bitfieldExtract(upos, 1, 1);
    uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
}
uint oct_00_0000_0001(uvec3 upos) {
    uvec3 a = bitfieldExtract(upos, 0, 1);
    uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
}

bool isSolidCell1(uvec3 upos, uint voxels, inout uint cell2Offset, inout Voxel v) {

    uint cellOct = oct_11_1100_0000(upos);

    // M5SubCell1
    uint bits    = voxelsIn[voxels+2+(cellOct*3)];
    uint bits2   = voxelsIn[voxels+2+(cellOct*3)+1];
    uint offset  = voxelsIn[voxels+2+(cellOct*3)+2];

    // M5SubCell2 oct
    uint suboct  = oct_00_0011_0000(upos);

    bool isAnAirCell  = bits==0 && bits2==0;
    bool isASolidCell = offset==0xffffffff;

    bool airSubcell = 0==(suboct < 32 ? bitfieldExtract(bits, int(suboct),     1) :
                                        bitfieldExtract(bits2, int(suboct-32), 1));

    bool solid = airSubcell || isASolidCell;

    if(solid) {
        // Solid air or solid stuff
        v.size  = isAnAirCell || isASolidCell ? 64 : 16;
        v.value = uint(isASolidCell || !airSubcell);
        v.oct   = cellOct;
    } else {
        // Drill down
        cell2Offset = offset + getImpliedIndex2(bits, bits2, suboct) * 3; // M5SubCell2.sizeof==12
    }
    return solid;
}
bool isSolidCell2(float distance, uvec3 upos, uint voxels, inout uint cellOffset, inout Voxel v) {
    // // M5SubCell2
    uint bits    = voxelsIn[voxels+cellOffset];
    uint bits2   = voxelsIn[voxels+cellOffset+1];
    uint offset  = voxelsIn[voxels+cellOffset+2];

    bool isAnAirCell  = bits==0 && bits2==0;
    bool isASolidCell = offset==0xffffffff;

    // M5SubCell3 oct
    uint oct  = oct_00_0000_1100(upos);

    bool air = 0==(oct < 32 ? bitfieldExtract(bits, int(oct),     1) :
                              bitfieldExtract(bits2, int(oct-32), 1));

    bool solid = air || isASolidCell;

    if(solid) {
        // Solid air or solid stuff
        v.size  = isAnAirCell || isASolidCell ? 16 : 4;
        v.value = uint(isASolidCell || !air);
    } else {
        // Drill down
        cellOffset = offset + getImpliedIndex2(bits, bits2, oct) * 2;  // M5SubCell3.sizeof==8
    }
    return solid;
}
bool isSolidCell3(float distance, uvec3 upos, uint voxels, inout uint cellOffset, inout Voxel v) {
    // M5SubCell3
    uint bits   = voxelsIn[voxels+cellOffset] & 0xff;
    uint offset = voxelsIn[voxels+cellOffset+1];

    bool isAnAirCell  = bits==0;
    bool isASolidCell = offset==0xffffffff;

    // M5Leaf oct
    uint oct  = oct_00_0000_0010(upos);

    bool air   = (bitfieldExtract(bits, int(oct), 1)==0);
    bool solid = air || isASolidCell;

    if(solid) {
        // Solid air or solid stuff
        v.size  = isAnAirCell || isASolidCell ? 4 : 2;
        v.value = uint(isASolidCell || !air);
    } else {
        // Drill down
        cellOffset = offset*4 + getImpliedIndex(bits, oct); // M5Leaf.sizeof=1
    }
    return solid;
}
void leaf(float distance, uvec3 upos, uint voxels, uint leafOffset, inout Voxel v) {
    // M5Leaf
    uint rem  = leafOffset&3;
    uint a    = voxelsIn[voxels+leafOffset/4];
    uint bits = a >> (rem*8);

    uint oct = oct_00_0000_0001(upos);

    v.size  = 1;
    v.value = uint(bitfieldExtract(bits, int(oct), 1)!=0);
}

///
/// Return true if we are inside an air voxel of some size.
/// Voxel is set accordingly.
///
bool getAirVoxel(Position pos, inout Voxel voxel, float distance, uint voxels) {
    uvec3 upos = pos.upos;

    uint offset;

    // isSolidCell1(upos, voxels, offset, voxel);
    // return voxel.value==0;


    // if(isSolidCell1(upos, voxels, offset, voxel)) return voxel.value==0;
    // isSolidCell2(distance, upos, voxels, offset, voxel);
    // return voxel.value==0;


    // if(isSolidCell1(upos, voxels, offset, voxel)) return voxel.value==0;
    // if(isSolidCell2(distance, upos, voxels, offset, voxel)) return voxel.value==0;
    // isSolidCell3(distance, upos, voxels, offset, voxel);
    // return voxel.value==0;


    if(isSolidCell1(upos, voxels, offset, voxel)) return voxel.value==0;
    if(isSolidCell2(distance, upos, voxels, offset, voxel)) return voxel.value==0;
    if(isSolidCell3(distance, upos, voxels, offset, voxel)) return voxel.value==0;

    leaf(distance, upos, voxels, offset, voxel);
    return voxel.value==0;
}
