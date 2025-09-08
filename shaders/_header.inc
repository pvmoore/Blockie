
#line 1 2

// All models
#define CHUNK_SIZE      (1024)
#define CHUNK_SIZE_SHR  (10)

// MODEL1 only:
#define OctreeTwigSize  (12)
#define OctreeLeafSize  (8)
#define DFIELD_OFFSET   (5152)

#define MAX_DISTANCE (15000)

struct Ray {
    vec3 start;
    vec3 direction;
    vec3 invDirection;
};

struct Position {
    uvec3 upos; // current worldcoords position relative to BB min (truncated uint)
    vec3 fpos;  // actual current worldcoords position (float)
    int chunk;  // offset into chunkDataIn
};

struct Voxel {
    uint size;      // 0,1,2,4,8,16,32,64,128,256,512,1024
    uint value;     // 0 or 1 (Model2)
    uint oct;       // only required for cells
    //uint normal;    // 0 to 5 axis-aligned normal estimate
    float distance; // Hit distance from camera
};

struct MarchOut {
    float distance;
    uint voxel;
};
///
/// Truncate vector to an axis aligned normal.
///
vec3 normaliseToAxis(vec3 v) {
    vec3 a = abs(v);
    vec3 b = a.x>=a.y && a.x>=a.z ? vec3(1,0,0) :
             a.y>=a.z ? vec3(0,1,0) : vec3(0,0,1);
    return b * sign(v);
}

