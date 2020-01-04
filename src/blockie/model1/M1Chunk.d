module blockie.model1.M1Chunk;

import blockie.all;
import blockie.model.Chunk;
/**
 *  y    z
 *  |   /----------
 *  |  /  2 /  3 /
 *  | /----------
 *  |/  0 /  1 /
 *  |----------x
 */
final class M1Chunk : Chunk {
public:
    /// Creates an air chunk
    this(chunkcoords coords) {
        super(coords);

        /// Set to air
        voxels.length = OctreeFlags.sizeof;
        auto r = root();
        r.flags.flag = OctreeFlag.AIR;
        r.flags.distance.clear();
    }

    override bool isAir() {
        return root().flags.flag==OctreeFlag.AIR;
    }

    OptimisedRoot* root() { return cast(OptimisedRoot*)voxels.ptr; }
}
//-----------------------------------------------------------------------------------
align(1):

enum OctreeFlag : ubyte {
    NONE  = 0,
    AIR   = 1,
    MIXED = 2
}

struct OctreeFlags { static assert(OctreeFlags.sizeof==8); align(1):
    OctreeFlag flag;
    ubyte _reserved;
    Distance6 distance;
}

