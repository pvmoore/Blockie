module blockie.model.model1a.M1aChunk;

import blockie.model;

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

    M1aOptRoot* optRoot()   { return cast(M1aOptRoot*)voxels.ptr; }
}

enum M1aFlag : ubyte {
    AIR = 0,
    MIXED
}

align(1) struct M1aFlags { static assert(M1aFlags.sizeof==8); align(1):
    M1aFlag flag;
    ubyte _reserved;
    Distance6 distance;
}

struct M1aLeaf { static assert(M1aLeaf.sizeof==8); align(1):
    ubyte[8] voxels;

    ubyte getVoxel(uint oct) {
        ASSERT(oct<8);
        return voxels[oct];
    }
    // If all the voxels are the same then solid is true
    bool isSolid() {
        ubyte v = getVoxel(0);
        for(auto i=1; i<voxels.length; i++) {
            if(getVoxel(i)!=v) return false;
        }
        return true;
    }
    void setVoxel(uint oct, ubyte v) {
        ASSERT(oct<8);
        voxels[oct] = v;
    }
    void setAllVoxels(ubyte v) {
        voxels[] = v;
    }
    string toString() { return "Leaf(%s)".format(voxels); }
}