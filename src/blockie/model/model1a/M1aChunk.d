module blockie.model.model1a.M1aChunk;

import blockie.all;
import blockie.model;
import blockie.model.model1a;

enum M1aFlag : ubyte {
    AIR,
    MIXED
}

align(1) struct M1aFlags { static assert(M1aFlags.sizeof==8); align(1):
    M1aFlag flag;
    ubyte _reserved;
    Distance6 distance;
}

final class M1aChunk : Chunk {
public:
    /// Creates an air chunk
    this(chunkcoords coords) {
        super(coords);

        /// Set to air
        voxels.length = M1aFlag.sizeof;
        auto r = optRoot();
        r.flags.flag = M1aFlag.AIR;
        r.flags.distance.clear();
    }

    override bool isAir() {
        return optRoot().flags.flag==M1aFlag.AIR;
    }

    M1aEditRoot* editRoot() { return cast(M1aEditRoot*)voxels.ptr; }
    M1aOptRoot* optRoot()   { return cast(M1aOptRoot*)voxels.ptr; }
}