
uint getImpliedIndex_8bit(const uint bits, const uint oct) {
    const uint and = 0x7f >> (7-oct);
    return bitCount(bits & and);
}
uint getImpliedIndex_16bit(const uint bits, const uint oct) {
    const uint and = 0x7fff >> (15-oct);
    return bitCount(bits & and);
}

/// Return true if chunk changes
bool updatePosition(inout Position pos, vec3 add) {
    pos.fpos += add;
    pos.upos  = ivec3(floor(pos.fpos-WORLD_BB[0]));

    uvec3 xyz = pos.upos >> CHUNK_SIZE_SHR;

	bool outOfBounds = any(greaterThanEqual(xyz, WORLD_CHUNKS_XYZ));

    int prevChunk = pos.chunk;
    pos.chunk = outOfBounds ? -1 : int(dot(xyz, CHUNKS_MUL));
    return pos.chunk != prevChunk;
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
// Calculate the minimum distance to the edge of the current voxel of size _voxelSize_.
//
float getMinDistToEdge(Ray ray, Position pos, uint voxelSize) {
    vec3 p    = pos.fpos-WORLD_BB[0];
    vec3 rem  = mod(p, voxelSize);
    vec3 size = vec3(greaterThanEqual(ray.direction, vec3(0))) * voxelSize;
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

    vec3 p    = pos.fpos-WORLD_BB[0];
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

    vec3 p    = pos.fpos-WORLD_BB[0];
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
    vec3 up   = radius >> 4;   // high 45 bits = up distance
    vec3 down = radius & 15;   // low  45 bits = down distance

    vec3 p    = pos.fpos-WORLD_BB[0];
    vec3 rem  = mod(p, voxelSize) + down*voxelSize;
    vec3 size = vec3(greaterThanEqual(ray.direction, vec3(0))) * ((1+up+down)*voxelSize);
    vec3 dist = size-rem;

    vec3 m    = dist * ray.invDirection;
    float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}

float getMinDistToEdgeUniDirectional(
    const Ray ray,
    const Position pos,
    const vec3 radius,
    const uint sideSize)    // CHUNK_SIZE or CELL_SIZE
{
    // radius = 0 = 1 air chunk  (r=0,    r2=0)
    //        = 1 = 3 air chunks (r=512,  r2=1024)
    //        = 2 = 5 air chunks (r=1024, r2 = 2048)
    //          etc...
    const vec3 r    = radius*sideSize;
    const vec3 r2   = r*2;
    const vec3 p    = pos.fpos-WORLD_BB[0];
    const vec3 rem  = mod(p, sideSize) + r;
    const vec3 size = vec3(greaterThanEqual(ray.direction, vec3(0))) * (sideSize+r2);
    const vec3 dist = size-rem;

    const vec3 m    = dist * ray.invDirection;
    const float res = min(m.x, min(m.y, m.z));
    return max(res, 0);
}
// void clampPositionToVoxelEntryPoint(Ray ray, Position pos, uint voxelSize, inout float distance) {

//     vec3 dir    = -ray.direction;
//     vec3 invDir = -ray.invDirection;

//     vec3 p    = pos.fpos-WORLD_BB[0];
//     vec3 rem  = mod(p, voxelSize);
//     vec3 size = vec3(greaterThanEqual(dir, vec3(0))) * voxelSize;
//     vec3 dist = size-rem;

//     vec3 m    = dist * invDir;
//     float res = min(m.x, min(m.y, m.z));
//     float f   = max(res, 0);

//     distance -= f;

//     //updatePosition(pos, dir*f);
// }