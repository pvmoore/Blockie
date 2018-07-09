#ifndef HEADER_H
#define HEADER_H

#include "common.h"

/* Defined externally:
	#define CHUNK_SIZE         256
	#define CHUNK_SIZE_SHR     8
	#define OCTREE_ROOT_BITS   1
*/

#pragma OPENCL EXTENSION cl_khr_byte_addressable_store : enable
#pragma OPENCL EXTENSION cl_khr_gl_sharing : enable


constant float3 lightPos = (float3)(1000,10000,-700);

#define CHUNK_SIZE_SQUARED (CHUNK_SIZE*CHUNK_SIZE)

//#pragma unroll <unroll-factor>
// __attribute__ ((endian(host)))
// __attribute__ ((aligned (1)))
// __attribute__((ext_vector_type(3))

typedef struct PACKED Ray_struct { // 64 bytes
    float3 start;
    float3 direction;
    float3 invDirection;
} Ray;

typedef struct PACKED BBox_struct { // 32
    float3 bounds[2] PACKED;
} BBox;

typedef struct PACKED Constants_struct { // 132
    BBox worldBB;	    // 32 bytes
    float3 cameraOrigin; // 16 bytes
    float3 cameraUp;     // 16 bytes
    float3 screenMiddle; // 16 bytes
    float3 screenXDelta; // 16 bytes
    float3 screenYDelta; // 16 bytes
    uint width;
    uint height;
	uint chunksX;
	uint chunksY;
	uint chunksZ;
} Constants;

typedef struct PACKED Chunk_struct { // 4 bytes
    uint voxelsOffset;
} Chunk;

typedef struct PACKED OctreeLeaf_struct { // 8
    uchar voxels[8];
} OctreeLeaf;

typedef struct PACKED OctreeIndex_struct { // 3
    uchar v[3];
} OctreeIndex;

typedef struct PACKED OctreeBranch_struct { // 1+3*8 = 25
    uchar bits;
    OctreeIndex indexes[8];
} OctreeBranch;

#if OCTREE_ROOT_BITS==1
typedef struct PACKED OctreeRoot_struct { // 26 bytes
    uchar flag;
    uchar bits;
    OctreeIndex indexes[8];
} OctreeRoot;
#endif

#if OCTREE_ROOT_BITS==2
typedef struct PACKED OctreeRoot_struct { // 201 bytes
    uchar flag;
    uchar bits[8];
    OctreeIndex indexes[64];
} OctreeRoot;
#endif

#if OCTREE_ROOT_BITS==3
typedef struct PACKED OctreeRoot_struct { // 1601 bytes
    uchar flag;
    uchar bits[64];
    OctreeIndex indexes[512];
} OctreeRoot;
#endif

#if OCTREE_ROOT_BITS==4
typedef struct PACKED OctreeRoot_struct { // 12801
    uchar flag;
    uchar bits[512];
    OctreeIndex indexes[4096];
} OctreeRoot;
#endif

#if OCTREE_ROOT_BITS==5
typedef struct PACKED OctreeRoot_struct { // 102401
    uchar flag;
    uchar bits[4096];
    OctreeIndex indexes[32768];
} OctreeRoot;
#endif

typedef struct PACKED Voxel_struct { // 3
    ushort size;
    uchar value;
} Voxel;

typedef struct PACKED Position_struct { // 8+8+8+16+16 = 56
    const global uchar* restrict voxelData;
    const global uchar* restrict chunkData;
    const global Chunk* chunk;
    uint3 worldSizeInChunks;
    uint3 upos;
    float3 fpos;
} Position;

typedef struct PACKED ShadeConstants_struct { // 24
    uint width;
    uint height;
    float3 sunPos;
} ShadeConstants;

// load 3 (possibly unaligned) little-endian bytes into a uint
inline uint load3Bytes(const global uchar* p) {
//    const uchar3 chars = vload3(0, p);
//    return chars.x | (chars.y<<8) | (chars.z<<16);
    return p[0] | (p[1]<<8) | (p[2]<<16);
}

inline const global uchar* getChunkVoxels(const Position* pos) {
    return &pos->voxelData[pos->chunk->voxelsOffset];
}

//----------------------------------------------------
#include "debug.c"
#include "bbox.c"
#include "voxel.c"
#include "getoctet.c"
#include "chunk.c"

#endif