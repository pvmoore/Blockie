
uint getImpliedIndex_8bit(const uint bits, const uint oct) {
    const uint and = 0x7f >> (7-oct);
    return bitCount(bits & and);
}
uint getImpliedIndex_16bit(const uint bits, const uint oct) {
    const uint and = 0x7fff >> (15-oct);
    return bitCount(bits & and);
}
uint getImpliedIndex_32bit(const uint bits, const uint oct) {
    uint and = 0x7fffffffu >> (31-oct);
    return bitCount(bits & and);
}

uint bitsRequiredToEncode(uint value) {
    return value<3 ? 1 : findMSB(value-1)+1;
}

/**
 *  Return lowest multiple of 8 bits that will contain _numBits_. eg. 10 = 2 bytes
 */
uint countBytes(uint numBits) {
    return ((numBits + 7) & ~7u) >> 3;
}
/**
 *  Return lowest multiple of 32 bits that will contain _numBits_. eg. 63 = 2 uints
 */
uint countUints(uint numBits) {
    return ((numBits + 31) & ~31u) >> 5;
}

/**
 *  Assumes numBits is between 1 and 32.
 */
uint getBits_voxelsIn(uint byteIndex, uint bitOffset, int numBits) {
    byteIndex += bitOffset/8;
    bitOffset &= 7u;
    const uint uintIndex = byteIndex/4;
    const uint uintRem   = byteIndex&3u;
    const int bitpos     = int(bitOffset + (uintRem*8));
    const int numBits2   = max(0, numBits - (32-bitpos));
    numBits -= numBits2;

    return bitfieldExtract(voxelsIn[uintIndex], bitpos, numBits) +
          (bitfieldExtract(voxelsIn[uintIndex+1], 0, numBits2) << numBits);
}

/// Return true if chunk changes
bool updatePosition(inout Position pos, vec3 add) {
    pos.fpos += add;
    pos.upos  = ivec3(floor(pos.fpos-ubo_WORLD_BB_MIN));

    uvec3 xyz = pos.upos >> CHUNK_SIZE_SHR;

	bool outOfBounds = any(greaterThanEqual(xyz, ubo_WORLD_CHUNKS_XYZ));

    int prevChunk = pos.chunk;
    pos.chunk = outOfBounds ? -1 : int(dot(xyz, CHUNKS_MUL));
    return pos.chunk != prevChunk;
}
// Update position - assumes the chunks does not change
void updatePositionWithinCell(inout Position pos, vec3 add) {
    pos.fpos += add;
    pos.upos  = ivec3(floor(pos.fpos-ubo_WORLD_BB_MIN));
}

///
/// Skip dist a little bit depending on how near to the camera
/// the ray is. This is necessary in the pathological case
/// where the ray is parallel to and on the edge of a voxel box.
/// Also, a small bump greatly improves speed without compromising
/// quality (much). Adjust these values appropriately depending on the scene.
///
void skipLOD(float distance, inout float dist) {
    float bump = (distance+0.00001)/1500;

    // handle pathological case
    if(dist<0.0001) {
        //dist += clamp(bump, 0.005, 0.5);
        dist += clamp(bump, 0.001, 2.0); // 0.001, 2.0
    } else {
        // skip a bit based on distance to camera
        //dist += clamp(bump, 0.0001, 15);
        /// The higher this value, the less accurate the results
        //dist += clamp(bump, 0.0001, 0.5);

        dist += smoothstep(0.00001, 1.5, bump); // 0.0001, 0.5
    }
}

//
// Calculate the minimum distance to the edge of the current volume of size _volumeSize_.
//
float getMinDistToEdge(Ray ray, Position pos, uint volumeSize) {
    vec3 p    = pos.fpos-ubo_WORLD_BB_MIN;
    vec3 rem  = mod(p, volumeSize);
    vec3 size = vec3(greaterThanEqual(ray.direction, vec3(0))) * volumeSize;
    vec3 dist = size-rem;

    vec3 m    = dist * ray.invDirection;
    float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}

//
// Calculate the minimum distance to the edge of the current volumn of size _volumeSize_
//
float getMinDistToEdge(Ray ray, Position pos, uvec3 volumeSize) {
    vec3 p    = pos.fpos-ubo_WORLD_BB_MIN;
    vec3 rem  = mod(p, volumeSize);
    vec3 size = vec3(greaterThanEqual(ray.direction, vec3(0))) * volumeSize;
    vec3 dist = size-rem;

    vec3 m    = dist * ray.invDirection;
    float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}

//
// Calculate the minimum distance to the edge of the distance field.
//
// @param radius : 8-bit up and down per axis
//
float getMinDistToEdge8BitsBiDirectional(Ray ray, Position pos, uvec3 radius, uint voxelSize) {
    uvec3 upradius   = radius >> 8u;        // high 8 bits = up distance
    uvec3 downradius = radius & 0xffu;      // low  8 bits = down distance

    vec3 p    = pos.fpos-ubo_WORLD_BB_MIN;
    vec3 rem  = mod(p, voxelSize) + downradius*voxelSize;
    vec3 size = vec3(greaterThanEqual(ray.direction, vec3(0))) * ((1+upradius+downradius)*voxelSize);
    vec3 dist = size-rem;

    vec3 m    = dist * ray.invDirection;
    float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}
//
// Calculate the minimum distance to the edge of the distance field.
//
// @param radius : 5-bit up and down per axis
//
float getMinDistToEdge5BitsBiDirectional(Ray ray, Position pos, uvec3 radius, uint voxelSize) {
    // Extract distance values
    vec3 up   = radius >> 5;   // high 5 bits = up distance
    vec3 down = radius & 31;   // low  5 bits = down distance

    vec3 p    = pos.fpos-ubo_WORLD_BB_MIN;
    vec3 rem  = mod(p, voxelSize) + down*voxelSize;
    vec3 size = vec3(greaterThanEqual(ray.direction, vec3(0))) * ((1+up+down)*voxelSize);
    vec3 dist = size-rem;

    vec3 m    = dist * ray.invDirection;
    float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}
//
// Calculate the minimum distance to the edge of the distance field.
//
// @param radius : 4-bit up and down per axis
//
float getMinDistToEdge4BitsBiDirectional(Ray ray, Position pos, uvec3 radius, uint voxelSize) {
    // Extract distance values
    vec3 up   = radius >> 4;   // high 4 bits = up distance
    vec3 down = radius & 15;   // low  4 bits = down distance

    vec3 p    = pos.fpos-ubo_WORLD_BB_MIN;
    vec3 rem  = mod(p, voxelSize) + down*voxelSize;
    vec3 size = vec3(greaterThanEqual(ray.direction, vec3(0))) * ((1+up+down)*voxelSize);
    vec3 dist = size-rem;

    vec3 m    = dist * ray.invDirection;
    float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}
// @param sideSize : CHUNK_SIZE or CELL_SIZE
float getMinDistToEdgeUniDirectional(Ray ray, Position pos, vec3 radius, uint sideSize) {
    // radius = 0 = 1 air chunk  (r=0,    r2=0)
    //        = 1 = 3 air chunks (r=512,  r2=1024)
    //        = 2 = 5 air chunks (r=1024, r2 = 2048)
    //          etc...
    vec3 r    = radius*sideSize;
    vec3 r2   = r*2;
    vec3 p    = pos.fpos-ubo_WORLD_BB_MIN;
    vec3 rem  = mod(p, sideSize) + r;
    vec3 size = vec3(greaterThanEqual(ray.direction, vec3(0))) * (sideSize+r2);
    vec3 dist = size-rem;

    vec3 m    = dist * ray.invDirection;
    float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}
// void clampPositionToVoxelEntryPoint(Ray ray, Position pos, uint voxelSize, inout float distance) {

//     vec3 dir    = -ray.direction;
//     vec3 invDir = -ray.invDirection;

//     vec3 p    = pos.fpos-ubo_WORLD_BB_MIN;
//     vec3 rem  = mod(p, voxelSize);
//     vec3 size = vec3(greaterThanEqual(dir, vec3(0))) * voxelSize;
//     vec3 dist = size-rem;

//     vec3 m    = dist * invDir;
//     float res = min(m.x, min(m.y, m.z));
//     float f   = max(res, 0);

//     distance -= f;

//     //updatePosition(pos, dir*f);
// }

// (0-2097151)
uint getOctet_1111111000(uvec3 upos) {
    uvec3 a = bitfieldExtract(upos, 3, 7); // offset 3, 7 bits
    uvec3 c = a << uvec3(0,7,14);
    return c.x + c.y + c.z;
}
/// (0-32767)
uint getOctet_1111100000(uvec3 upos) {
    // 11_1110_0000 -> 0zzz_zzyy_yyyx_xxxx
    uvec3 a = bitfieldExtract(upos, 5, 5);
    uvec3 c = a << uvec3(0,5,10);
    return c.x + c.y + c.z;
}
/// (0-32767)
uint getOctet_0000011111(uvec3 upos) {
    // 00_0001_11111 -> 0zzz_zzyy_yyyx_xxxx
    uvec3 a = bitfieldExtract(upos, 0, 5);
    uvec3 c = a << uvec3(0,5,10);
    return c.x + c.y + c.z;
}

/// (0-4095)
uint getOctet_1111000000(const uvec3 inXYZ) {
    // 11_1100_0000 -> zzzz_yyyyxxxx
    const uvec3 a = bitfieldExtract(inXYZ, 6, 4);
    const uvec3 c = a << uvec3(0,4,8);
    return c.x + c.y + c.z;
}
// (0-63)
uint getOctet_0000110000(uvec3 upos) {
    uvec3 a = bitfieldExtract(upos, 4, 2);
    uvec3 c = a << uvec3(0,2,4);
    return c.x + c.y + c.z;
}
// (0-63)
uint getOctet_0000001100(uvec3 upos) {
    uvec3 a = bitfieldExtract(upos, 2, 2);
    uvec3 c = a << uvec3(0,2,4);
    return c.x + c.y + c.z;
}
/// (0-7)
uint getOctet_0000100000(uvec3 inXYZ) {
	// x = 0010_0000
	// y = 0010_0000  >  oct = 00000zyx
	// z = 0010_0000
	const uvec3 a = bitfieldExtract(inXYZ, 5, 1);
    const uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
}
/// (0-7)
uint getOctet_0000010000(uvec3 inXYZ) {
	// x = 0001_0000
	// y = 0001_0000  >  oct = 00000zyx
	// z = 0001_0000
	const uvec3 a = bitfieldExtract(inXYZ, 4, 1);
    const uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
}
/// (0-7)
uint getOctet_0000001000(uvec3 inXYZ) {
	// x = 0000_1000
	// y = 0000_1000  >  oct = 00000zyx
	// z = 0000_1000
	const uvec3 a = bitfieldExtract(inXYZ, 3, 1);
    const uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
}
/// (0-7)
uint getOctet_0000000100(const uvec3 inXYZ) {
	// x = 0000_0100
	// y = 0000_0100  >  oct = 00000zyx
	// z = 0000_0100
	const uvec3 a = bitfieldExtract(inXYZ, 2, 1);
    const uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
}
/// (0-7)
uint getOctet_0000000010(const uvec3 inXYZ) {
	// x = 0000_0010
	// y = 0000_0010  >  oct = 00000zyx
	// z = 0000_0010
	const uvec3 a = bitfieldExtract(inXYZ, 1, 1);
	const uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
}
/// (0-7)
uint getOctet_0000000001(const uvec3 inXYZ) {
	// x = 0000_0001
	// y = 0000_0001  >  oct = 00000zyx
	// z = 0000_0001
	//const uvec3 a = inXYZ & 1u;
	const uvec3 a = bitfieldExtract(inXYZ, 0, 1);
	const uvec3 c = a << uvec3(0,1,2);
	return c.x + c.y + c.z;
}

/// (0-7)
uint getOctet_1_and(const uvec3 inXYZ, const uint and) {
    // if and==32:
	// x = 0_0010_0000
	// y = 0_0010_0000  >  oct = 00000zyx
	// z = 0_0010_0000
	const int SHR = findLSB(and);
	const uvec3 a = bitfieldExtract(inXYZ, SHR, 1);
    const uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
}
// (0-7)
uint getOctet_n_1(uvec3 upos, int bitpos) {
	uvec3 a = bitfieldExtract(upos, bitpos, 1);
    uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
}
uint getOctet_n_n(uvec3 upos, int bitOffset, int numBits) {
    uvec3 a = bitfieldExtract(upos, bitOffset, numBits);
    uvec3 c = a << uvec3(0,numBits,numBits+numBits);
    return c.x + c.y + c.z;
}


uint get3Bytes(uint voxels, uint index) {
    uint a  = (index & 3);
    uint i  = (index * 3) >> 2;
    uint d1 = voxelsIn[voxels + i];
    uint d2 = a==1 || a==2 ? voxelsIn[voxels + i + 1] : 0;

    return a == 0 ? d1 & 0xffffffu :
           a == 1 ? (d1>>24)   | ((d2 & 0xffffu) << 8) :
           a == 2 ? (d1 >> 16) | ((d2 & 0xffu) << 16) :
                    d1 >> 8;
}