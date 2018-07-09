#ifndef VOXEL_C
#define VOXEL_C

#define V_AIR 0
#define V_EARTH1 10
#define V_ROCK1 11
#define V_GRASS1 12

constant const float4 uchar_to_pixel[] = {
    // volumetric
	(float4)(0,0, 0.25, 1),	    // [0] V_AIR (space)
    (float4)(0,0,1, 1),         // [1] water
    (float4)(0.7,0.7,0.7, 1),   // [2] smoke
    // reserved
    (float4)(0,0,0, 1),         // [3] reserved
    (float4)(0,0,0, 1),         // [4] reserved
    (float4)(0,0,0, 1),         // [5] RESERVED
    (float4)(0,0,0, 1),         // [6] reserved
    (float4)(0,0,0, 1),         // [7] reserved
    (float4)(0,0,0, 1),         // [8] reserved
    (float4)(0,0,0, 1),         // [9] reserved

    // single voxels
	(float4)(0.3, 0.15, 0.15, 1),	// [10] V_EARTH1
	(float4)(0.5, 0.5,  0.5, 1),    // [11] V_ROCK1
	(float4)(0.2, 0.7,  0.2, 1),	// [12] V_GRASS1
	(float4)(1.0, 1.0,  1.0, 1)		// [13] V_SNOW
};

inline float4 getDiffuse(uchar voxel) {
    return uchar_to_pixel[voxel];
}

#endif // VOXEL_C