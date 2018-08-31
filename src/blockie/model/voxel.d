module blockie.model.voxel;

import blockie.all;

final enum : ubyte {
// volumetric. size (1..CHUNK_SIZE) voxels
    V_AIR     = 0,
    V_WATER   = 1, // todo - should this be volumetric?
    V_SMOKE   = 2,

// size 1 terrain voxels
    V_EARTH1 = 10,
    V_ROCK1  = 11,
    V_GRASS1 = 12,
    V_SNOW   = 13,
    V_SAND   = 14,

    V_LAST   = 255
}

//__gshared const Vector3[] DIFFUSE_VOXEL_VALUE = [
//    // volumetric
//	Vector3(0,0, 0.25),	    // [0] V_AIR (space)
//    Vector3(0,0,1),         // [1] water
//    Vector3(0.7,0.7,0.7),   // [2] smoke
//    // reserved
//    Vector3(0,0,0),         // [3] reserved
//    Vector3(0,0,0),         // [4] reserved
//    Vector3(0,0,0),         // [5] RESERVED
//    Vector3(0,0,0),         // [6] reserved
//    Vector3(0,0,0),         // [7] reserved
//    Vector3(0,0,0),         // [8] reserved
//    Vector3(0,0,0),         // [9] reserved
//
//    // single voxels
//	Vector3(0.352, 0.367, 0.363),	// [10] V_EARTH1
//	Vector3(0.5, 0.5,  0.5),    // [11] V_ROCK1
//	Vector3(0.2, 0.7,  0.2),	// [12] V_GRASS1
//	Vector3(1.0, 1.0,  1.0)		// [13] V_SNOW
//];

/**
 *  Select modal average voxel.
 */
ubyte getAverageVoxel(ubyte[8] voxels) {
    static uint[ubyte] map;

    foreach(v; voxels) {
        uint count = map.get(v, 0);
        map[v] = count+1;
    }
    uint most = 0;
    ubyte voxel;
    foreach(k,v; map) {
        if(v>most || (v==most && voxel==0)) {
            most  = v;
            voxel = k;
        }
    }
//    writefln("voxels=%s", voxels);
//    writefln("map=%s", map);
//    writefln("most=%s", most);
//    writefln("voxel=%s", voxel);

    map.clear();
    return voxel;
}