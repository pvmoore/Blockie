module blockie.model1.M1ChunkOptView;

import blockie.model;

align(1):

struct OptimisedRoot { static assert(OptimisedRoot.sizeof==13344);
                       static assert(OptimisedRoot.bitsAndPopcnts.offsetof%4==0);
                       static assert(OptimisedRoot.voxels.offsetof%4==0);
                       static assert(OptimisedRoot.dfields.offsetof%4==0); align(1):
    OctreeFlags flags;  // 8 bytes
    uint twigsOffset;
    uint l2TwigsOffset;
    uint leavesOffset;
    uint l2IndexOffset;
    uint leafIndexOffset;
    uint encodeBits;    // (leafEncodeBits | (l2EncodeBits<<8))

    uint[M1_CELLS_PER_CHUNK/16] bitsAndPopcnts; /// 256 uints
    ubyte[M1_CELLS_PER_CHUNK] voxels;           /// 4096 ubytes
    ushort[M1_CELLS_PER_CHUNK] dfields;         /// 4096 ushorts (5bits per axis uni directional)



    bool isSolid(uint oct) {
        auto uintIndex = oct>>4;
        auto bitIndex  = oct&15;
        uint bits      = bitsAndPopcnts[uintIndex] & 0xffff;
        return (bits & (1<<bitIndex))==0;
    }
    bool isAir(uint oct) {
        return isSolid(oct) && voxels[oct]==0;
    }
    uint getOctree(uint x, uint y, uint z) {
        return x | (y<<M1_OCTREE_ROOT_BITS) | (z<<(M1_OCTREE_ROOT_BITS*2));
    }
    uint getOctree(int3 i) {
        return getOctree(i.x, i.y, i.z);
    }
    void setDField(uint oct, uint x, uint y, uint z) {
        //expect(oct<OCTREE_ROOT_INDEXES_LENGTH);

        /// We only have 5 bits per axis
        x = minOf(31, x);
        y = minOf(31, y);
        z = minOf(31, z);

        dfields[oct] = cast(ushort)(x | (y<<5) | (z<<10));
    }
}

struct OctreeTwig { static assert(OctreeTwig.sizeof==12); align(1):
    ubyte bits;
    ubyte[3] baseIndex;
    ubyte[8] voxels;

    uint getBaseIndex() {
        return (baseIndex[2]<<16) | (baseIndex[1]<<8) | baseIndex[0];
    }
    void setBaseIndex(uint b) {
        baseIndex[0] = cast(ubyte)(b&0xff);
        baseIndex[1] = cast(ubyte)(b>>8)&0xff;
        baseIndex[2] = cast(ubyte)(b>>16)&0xff;
    }
}
