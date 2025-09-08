#language slang 2026
implementing blockie;

public struct Flags {
    public uint a;
    public uint b;
}
[ForceInline] public uint CHUNK_FLAG(Flags f) { return (f.a & 0xffu); }
[ForceInline] public uint CHUNK_DISTANCE_X(Flags f) { return (f.a >> 16); }
[ForceInline] public uint CHUNK_DISTANCE_Y(Flags f) { return (f.b & 0xffffu); }
[ForceInline] public uint CHUNK_DISTANCE_Z(Flags f) { return (f.b >> 16); }

/**
 *  Fetch 1 byte of data at voxelsIn[voxels + 'byteIndex']
 */
public uint getByte(const VoxelsBuffer voxelsIn, uint voxels, uint byteIndex) {
    uint uintIndex = byteIndex / 4;
    uint shift = (byteIndex & 3) * 8;
    return (voxelsIn[voxels + uintIndex] >> shift) & 0xffu;
}

/**
 *  Fetch 2 bytes of data at voxelsIn[voxels + 'wordIndex']
 */
public uint getUshort(const VoxelsBuffer voxelsIn, uint voxels, uint wordIndex) {
    uint uintIndex = wordIndex / 2;
    uint shift = (wordIndex & 1) * 16;
    return (voxelsIn[voxels + uintIndex] >> shift) & 0xffffu;
}

/**
 *  Assumes numBits is between 1 and 32.
 */
public uint getBits(const VoxelsBuffer voxelsIn, uint byteIndex, uint bitOffset, int numBits) {
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

/// (0-7)
public uint getOctet_0000000001(const uint3 inXYZ) {
	// x = 0000_0001
	// y = 0000_0001  >  oct = 00000zyx
	// z = 0000_0001
	//const uvec3 a = inXYZ & 1u;
	const uint3 a = bitfieldExtract(inXYZ, 0, 1);
	const uint3 c = a << uint3(0,1,2);
	return c.x + c.y + c.z;
}
/// (0-7)
public uint getOctet_0000000010(const uint3 inXYZ) {
	// x = 0000_0010
	// y = 0000_0010  >  oct = 00000zyx
	// z = 0000_0010
	const uint3 a = bitfieldExtract(inXYZ, 1, 1);
	const uint3 c = a << uint3(0,1,2);
    return c.x + c.y + c.z;
}

/// (0-7)
public uint getOctet_0000000100(const uint3 inXYZ) {
	// x = 0000_0100
	// y = 0000_0100  >  oct = 00000zyx
	// z = 0000_0100
	const uint3 a = bitfieldExtract(inXYZ, 2, 1);
    const uint3 c = a << uint3(0,1,2);
    return c.x + c.y + c.z;
}

/// (0-7)
public uint getOctet_0000010000(uint3 inXYZ) {
	// x = 0001_0000
	// y = 0001_0000  >  oct = 00000zyx
	// z = 0001_0000
	const uint3 a = bitfieldExtract(inXYZ, 4, 1);
    const uint3 c = a << uint3(0,1,2);
    return c.x + c.y + c.z;
}

/// (0-7)
public uint getOctet_0000100000(uint3 inXYZ) {
	// x = 0010_0000
	// y = 0010_0000  >  oct = 00000zyx
	// z = 0010_0000
	const uint3 a = bitfieldExtract(inXYZ, 5, 1);
    const uint3 c = a << uint3(0,1,2);
    return c.x + c.y + c.z;
}

/// (0-4095)
public uint getOctet_1111000000(const uint3 inXYZ) {
    // 11_1100_0000 -> zzzz_yyyyxxxx
    const uint3 a = bitfieldExtract(inXYZ, 6, 4);
    const uint3 c = a << uint3(0,4,8);
    return c.x + c.y + c.z;
}

/// (0-32767)
public uint getOctet_1111100000(uint3 upos) {
    // 11_1110_0000 -> 0zzz_zzyy_yyyx_xxxx
    uint3 a = bitfieldExtract(upos, 5, 5);
    uint3 c = a << uint3(0,5,10);
    return c.x + c.y + c.z;
}

// (0-7)
public uint getOctet_n_1(uint3 upos, int bitpos) {
	uint3 a = bitfieldExtract(upos, bitpos, 1);
    uint3 c = a << uint3(0,1,2);
    return c.x + c.y + c.z;
}

/// (0-7)
public uint getOctet_1_and(const uint3 inXYZ, const uint and) {
    // if and==32:
	// x = 0_0010_0000
	// y = 0_0010_0000  >  oct = 00000zyx
	// z = 0_0010_0000
	const int SHR = firstbitlow(and);
	const uint3 a = bitfieldExtract(inXYZ, SHR, 1);
    const uint3 c = a << uint3(0,1,2);
    return c.x + c.y + c.z;
}

public uint getImpliedIndex_8bit(const uint bits, const uint oct) {
    const uint and = 0x7f >> (7-oct);
    return countbits(bits & and);
}

public uint getImpliedIndex_16bit(const uint bits, const uint oct) {
    const uint and = 0x7fff >> (15-oct);
    return countbits(bits & and);
}

///
/// Skip dist a little bit depending on how near to the camera
/// the ray is. This is necessary in the pathological case
/// where the ray is parallel to and on the edge of a voxel box.
/// Also, a small bump greatly improves speed without compromising
/// quality (much). Adjust these values appropriately depending on the scene.
///
public void skipLOD(float distance, inout float dist) {
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
public float getMinDistToEdge(const UBO ubo, const Ray ray, const Position pos, uint volumeSize) {
    float3 p    = pos.fpos-ubo.worldBBMin;
    float3 rem  = fmod(p, volumeSize);
    float3 size = float3(ray.direction >= float3(0)) * volumeSize;
    float3 dist = size-rem;

    float3 m    = dist * ray.invDirection;
    float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}

//
// Calculate the minimum distance to the edge of the distance field.
//
// @param radius : 4-bit up and down per axis
//
public float getMinDistToEdge4BitsBiDirectional(const UBO ubo, const Ray ray, const Position pos, uint3 radius, uint voxelSize) {
    // Extract distance values
    float3 up   = radius >> 4;   // high 4 bits = up distance
    float3 down = radius & 15;   // low  4 bits = down distance

    float3 p    = pos.fpos-ubo.worldBBMin;
    float3 rem  = fmod(p, voxelSize) + down*voxelSize;
    float3 size = float3(ray.direction >= float3(0)) * ((1+up+down)*voxelSize);
    float3 dist = size-rem;

    float3 m    = dist * ray.invDirection;
    float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}

//
// Calculate the minimum distance to the edge of the distance field.
//
// @param radius : 8-bit up and down per axis
//
public float getMinDistToEdge8BitsBiDirectional(const UBO ubo, const Ray ray, const Position pos, uint3 radius, uint voxelSize) {
    uint3 upradius   = radius >> 8u;        // high 8 bits = up distance
    uint3 downradius = radius & 0xffu;      // low  8 bits = down distance

    float3 p    = pos.fpos-ubo.worldBBMin;
    float3 rem  = fmod(p, voxelSize) + downradius*voxelSize;
    float3 size = float3(ray.direction >= float3(0)) * ((1+upradius+downradius)*voxelSize);
    float3 dist = size-rem;

    float3 m  = dist * ray.invDirection;
    float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}

// @param sideSize : CHUNK_SIZE or CELL_SIZE
public float getMinDistToEdgeUniDirectional(const UBO ubo, const Ray ray, const Position pos, float3 radius, uint sideSize) {
    // radius = 0 = 1 air chunk  (r=0,    r2=0)
    //        = 1 = 3 air chunks (r=512,  r2=1024)
    //        = 2 = 5 air chunks (r=1024, r2 = 2048)
    //          etc...
    float3 r    = radius*sideSize;
    float3 r2   = r*2;
    float3 p    = pos.fpos-ubo.worldBBMin;
    float3 rem  = fmod(p, sideSize) + r;
    float3 size = float3(ray.direction >= float3(0)) * (sideSize+r2);
    float3 dist = size-rem;

    float3 m    = dist * ray.invDirection;
    float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}
