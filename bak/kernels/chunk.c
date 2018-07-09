#ifndef CHUNK_C
#define CHUNK_C

#define ROOT   global OctreeRoot
#define LEAF   global OctreeLeaf
#define BRANCH global OctreeBranch
#define INDEX  global OctreeIndex

void updatePosition(Position* pos, float3 add) {
    pos->fpos += add;
    pos->upos  = toUint3_f3(pos->fpos);

    uint3 xyz = pos->upos;
	xyz >>= CHUNK_SIZE_SHR;

	bool outOfBounds = any(xyz >= pos->worldSizeInChunks);

    const uint chunksX  = pos->worldSizeInChunks.x;
	const uint chunksXY = pos->worldSizeInChunks.x*
	                      pos->worldSizeInChunks.y;

    pos->chunk =
        outOfBounds ? NULL
        : (const global Chunk*)
            (pos->chunkData+
             (xyz.x +
              xyz.y*chunksX +
              xyz.z*chunksXY)*sizeof(Chunk)
            );
}
inline float getMinDistToEdge(const Ray* ray,
                              const Position* pos,
                              const uint size)
{
    const float3 rem  = rem_f3f(pos->fpos, size);
    const float3 dist = ray->direction < 0 ? -rem : size-rem;
    const float3 m    = dist * ray->invDirection;
    const float res   = min_fff(m.x, m.y, m.z);
    return fmax(res, 0.0f);
}
// -----------------------------------------------------------------------------
inline bool isAirChunk(const ROOT* root) {
    return root->flag==1;
}
bool isSolidRoot(const global uchar* voxels,
                 ROOT** rootPtr,
                 const uint3 upos,
                 Voxel* v)
{
    const ushort SZ  = CHUNK_SIZE >> OCTREE_ROOT_BITS;
    const ROOT* root = *rootPtr;

#if OCTREE_ROOT_BITS==1
    const uint oct     = getOctet_1(upos, SZ);
    const bool solid   = 0==(root->bits & (1<<oct));
#else
    #if OCTREE_ROOT_BITS==2
        const uint oct   = getOctet_11(upos);
    #elif OCTREE_ROOT_BITS==3
        const uint oct   = getOctet_111(upos);
    #elif OCTREE_ROOT_BITS==4
        const uint oct   = getOctet_1111(upos);
    #elif OCTREE_ROOT_BITS==5
        const uint oct   = getOctet_11111(upos);
    #endif
    const uint byteIndex = oct>>3;
    const uint bitIndex  = oct&7;
    const bool solid     = 0==(root->bits[byteIndex] & (1<<bitIndex));
#endif

    const global void* p      = &root->indexes[oct];
    const global uchar* pchar = p;

    v->size  = select((ushort)0, SZ, (ushort)solid);
    v->value = select((uchar)0, *pchar, (uchar)solid);

    // this is faster but needs data to be 4-byte aligned
    //const global uint* pint   = p;
    //const uint offset = pint[0] & 0xffffff;
    const uint offset = load3Bytes(pchar);
    *rootPtr = (ROOT*)(voxels+offset);

    return solid;
}
bool isSolidBranch(const global uchar* voxels,
                   BRANCH** branchPtr,
                   const uint3 upos,
                   Voxel* v,
                   const ushort SZ)
{
    const BRANCH* branch = *branchPtr;
    const uint oct       = getOctet_1(upos, SZ);
    const bool solid     = 0==(branch->bits & (1<<oct));

    const global void* p      = &branch->indexes[oct];
    const global uchar* pchar = p;

    v->size  = select((ushort)0, SZ, (ushort)solid);
    v->value = select((uchar)0, *pchar, (uchar)solid);

    // this is faster but needs data to be 4-byte aligned
    //const global uint* pint   = p;
    //const uint offset = pint[0] & 0xffffff;
    const uint offset = load3Bytes(pchar);
    *branchPtr = (BRANCH*)(voxels+offset);

    return solid;
}
bool gavLeaf(const BRANCH* branch,
             const uint3 upos,
             Voxel* v)
 {
     const uint oct = getOctet_1(upos, 1);

     const global void* p      = &((LEAF*)branch)->voxels[oct];
     const global uchar* pchar = p;

     v->size  = 1;
     v->value = *pchar;

     return true;
 }
//-------------------------------------------------------------
#define BRANCH512 isSolidBranch(voxels, &branch, upos, voxel, 512)
#define BRANCH256 isSolidBranch(voxels, &branch, upos, voxel, 256)
#define BRANCH128 isSolidBranch(voxels, &branch, upos, voxel, 128)
#define BRANCH64 isSolidBranch(voxels, &branch, upos, voxel, 64)
#define BRANCH32 isSolidBranch(voxels, &branch, upos, voxel, 32)
#define BRANCH16 isSolidBranch(voxels, &branch, upos, voxel, 16)
#define BRANCH8 isSolidBranch(voxels, &branch, upos, voxel, 8)
#define BRANCH4 isSolidBranch(voxels, &branch, upos, voxel, 4)
#define BRANCH2 isSolidBranch(voxels, &branch, upos, voxel, 2)

#if CHUNK_SIZE==1024
    #undef BRANCH512
    #define BRANCH512 false

    #if OCTREE_ROOT_BITS>=2
        #undef BRANCH256
        #define BRANCH256 false
    #endif
    #if OCTREE_ROOT_BITS>=3
        #undef BRANCH128
        #define BRANCH128 false
    #endif
    #if OCTREE_ROOT_BITS>=4
        #undef BRANCH64
        #define BRANCH64 false
    #endif
    #if OCTREE_ROOT_BITS>=5
        #undef BRANCH32
        #define BRANCH32 false
    #endif
#endif

#if CHUNK_SIZE==512
    #undef BRANCH512
    #undef BRANCH256
    #define BRANCH512 false
    #define BRANCH256 false

    #if OCTREE_ROOT_BITS>=2
        #undef BRANCH128
        #define BRANCH128 false
    #endif
    #if OCTREE_ROOT_BITS>=3
        #undef BRANCH64
        #define BRANCH64 false
    #endif
    #if OCTREE_ROOT_BITS>=4
        #undef BRANCH32
        #define BRANCH32 false
    #endif
    #if OCTREE_ROOT_BITS>=5
        #undef BRANCH16
        #define BRANCH16 false
    #endif
#endif

#if CHUNK_SIZE==256
    #undef BRANCH512
    #undef BRANCH256
    #undef BRANCH128
    #define BRANCH512 false
    #define BRANCH256 false
    #define BRANCH128 false

    #if OCTREE_ROOT_BITS>=2
        #undef BRANCH64
        #define BRANCH64 false
    #endif
    #if OCTREE_ROOT_BITS>=3
        #undef BRANCH32
        #define BRANCH32 false
    #endif
    #if OCTREE_ROOT_BITS>=4
        #undef BRANCH16
        #define BRANCH16 false
    #endif
    #if OCTREE_ROOT_BITS>=5
        #undef BRANCH8
        #define BRANCH8 false
    #endif
#endif
#if CHUNK_SIZE==128
    #undef BRANCH512
    #undef BRANCH256
    #undef BRANCH128
    #undef BRANCH64
    #define BRANCH512 false
    #define BRANCH256 false
    #define BRANCH128 false
    #define BRANCH64 false

    #if OCTREE_ROOT_BITS>=2
        #undef BRANCH32
        #define BRANCH32 false
    #endif
    #if OCTREE_ROOT_BITS>=3
        #undef BRANCH16
        #define BRANCH16 false
    #endif
    #if OCTREE_ROOT_BITS>=4
        #undef BRANCH8
        #define BRANCH8 false
    #endif
    #if OCTREE_ROOT_BITS>=5
        #undef BRANCH4
        #define BRANCH4 false
    #endif
#endif
#if CHUNK_SIZE==64
    #undef BRANCH512
    #undef BRANCH256
    #undef BRANCH128
    #undef BRANCH64
    #undef BRANCH32
    #define BRANCH512 false
    #define BRANCH256 false
    #define BRANCH128 false
    #define BRANCH64 false
    #define BRANCH32 false

    #if OCTREE_ROOT_BITS>=2
        #undef BRANCH16
        #define BRANCH16 false
    #endif
    #if OCTREE_ROOT_BITS>=3
        #undef BRANCH8
        #define BRANCH8 false
    #endif
    #if OCTREE_ROOT_BITS>=4
        #undef BRANCH4
        #define BRANCH4 false
    #endif
    #if OCTREE_ROOT_BITS>=5
        #undef BRANCH2
        #define BRANCH2 false
    #endif
#endif

/// return true if air voxel found
/// Also sets voxel properties
bool getAirVoxel(const Position* pos, Voxel* voxel)
{
    const global uchar* voxels = getChunkVoxels(pos);
    BRANCH* branch = (BRANCH*)voxels;
    uint3 upos     = pos->upos;

    voxel->size = CHUNK_SIZE;

//    if(all(pos->upos==(uint3)(14,645,2047))) {
//
//    }

    bool r =
        isAirChunk((ROOT*)branch) ||
        isSolidRoot(voxels, (ROOT**)&branch, upos, voxel) ||
        BRANCH512 ||
        BRANCH256 ||
        BRANCH128 ||
        BRANCH64 ||
        BRANCH32 ||
        BRANCH16 ||
        BRANCH8 ||
        BRANCH4 ||
        BRANCH2 ||
        gavLeaf(branch, upos, voxel);

    return voxel->value==0;
}

#undef BRANCH512
#undef BRANCH256
#undef BRANCH128
#undef BRANCH64
#undef BRANCH32
#undef BRANCH16
#undef BRANCH8
#undef BRANCH4
#undef BRANCH2
#undef ROOT
#undef LEAF
#undef BRANCH
#undef INDEX

#endif // CHUNK_C