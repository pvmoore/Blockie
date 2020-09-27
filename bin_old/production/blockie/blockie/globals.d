module blockie.globals;

import maths : int3;

public:

/**
 * size 16   (4)  =         4,096 voxels
 * size 32   (5)  =        32,768 voxels
 * size 64   (6)  =       262,144 voxels
 * size 128  (7)  =     2,097,152 voxels (2MB)
 * size 256  (8)  =    16,777,216 voxels (16MB)
 * size 512  (9)  =   134,217,728 voxels (128MB)
 * size 1024 (10) = 1,073,741,824 voxels (1GB)
 */
const CHUNK_SIZE_SHR     = 10;   // 6 to 10
const CHUNK_SIZE         = 2^^CHUNK_SIZE_SHR;
const CHUNK_SIZE_SQUARED = CHUNK_SIZE*CHUNK_SIZE;

const KB = 1024;
const MB = 1024*1024;

alias worldcoords = int3;
alias chunkcoords = int3;

version(GC_STATS) {
    ///
    /// Show GC stats after program exits
    ///
    extern(C) __gshared string[] rt_options = [
        "gcopt=profile:1"
    ];
}
