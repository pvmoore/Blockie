module blockie.model.model1a.M1aChunkOptView;

import blockie.all;
import blockie.model;
import blockie.model.model1a;

/**
 * M1aOptRoot
 *  8 bytes    - M1aFlags
 *  512 bytes  - Cell air flag bits
 *  4096 bytes - Cell bits
 *  4096 bytes - Cell bits popcounts
 *  0-4096 * Distance3 (0-12288 bytes)
 *  0-4096 * Offset3 (0-12288 bytes)
 *
 * Branches:
 *  [optional] 8 bytes - voxels (if parent bits!=0xff)
 *  1-8 * M1aOptBranch
 *
 * Leaves:
 *  [optional] 8 bytes - voxels (if parent bits!=0xff)
 *  1-8 * M1aOptLeaf
 *
 * M1aOptBranch:
 *  4 bytes {
 *    1 byte bits
 *    3 bytes (offset)
 *  }
 *
 * M1aOptLeaf:
 *  8 bytes - voxels
 *
 */
align(1):

struct M1aOptRoot { //static assert(M1aOptRoot.sizeof==8+M1a_CELLS_PER_CHUNK/8);
align(1):
    M1aFlags flags;                             /// 8 bytes

    // Only if flags.flag == M1aFlag.MIXED
    ubyte[M1a_CELLS_PER_CHUNK/8] airFlags;      /// 1 bit per cell
    ubyte[M1a_CELLS_PER_CHUNK] cellBits;
    ubyte[M1a_CELLS_PER_CHUNK] cellBitsPopcounts;

    Distance3[] distances;  // unknown length
    Offset3[] offsets;      // unknown length
}
struct M1aOptBranch { static assert(M1aOptBranch.sizeof==4); align(1):
    ubyte bits;
    Offset3 offset;
}
// struct M1aOptLeaf { static assert(M1aOptLeaf.sizeof==8); align(1):
//     ubyte[8] voxels;
// }
