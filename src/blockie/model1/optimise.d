module blockie.model1.optimise;
/**
 * Optimised read-only voxels layout (assumes 10-bit chunk 4-bit root):
 *
 * Root:
 *      uint    flags
 *      uint    twigsOffset
 *      uint    l2TwigsOffset
 *      uint    leavesOffset
 *      uint    l2IndexOffset
 *      uint    leafIndexOffset
 *      uint    (leafEncodeBits | (l2EncodeBits<<8))
 *
 *      uint[256] root bits and popcounts interleaved (4096/16)
 *
 *      ubyte[4096]  root voxels (solid or LOD estimated)
 *      ushort[4096] root air distance fields (3*5 bits + 1 spare)
 *
 * Twigs: (12 bytes each)
 *      ubyte bits
 *      ubyte[3] index (into twigsOffset or if level=3 point to l2indexes)
 *      ubyte[8] voxels (solid or LOD estimated)
 * L2Twigs: (12 bytes each)
 *      Same as Twigs but base offset points to LeafIndexes
 * Leaves: (8 bytes each)
 *      ubyte[8] voxels
 * L2Indexes: (l2EncodeBits bits each)
 *      Indexes into l2TwigsOffset
 * LeafIndexes: (leafEncodeBits bits each)
 *      Indexes into leavesOffset
 */
import blockie.all;

__gshared ulong maxBranches;
__gshared ulong maxLeaves;
__gshared ulong maxVoxelsLength;
__gshared uint numChunksOptimised;


align(1) struct OptimisedRoot { align(1):
    OctreeFlags flags;
    uint twigsOffset;
    uint l2TwigsOffset;
    uint leavesOffset;
    uint l2IndexOffset;
    uint leafIndexOffset;
    uint encodeBits;    // (leafEncodeBits | (l2EncodeBits<<8))
    uint[OCTREE_ROOT_INDEXES_LENGTH/16] bitsAndPopcnts;
    ubyte[OCTREE_ROOT_INDEXES_LENGTH] voxels;
    ushort[OCTREE_ROOT_INDEXES_LENGTH] dfields;

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
        //expect(x<8 && y<8 && z<8);
        return x | (y<<M1_OCTREE_ROOT_BITS) | (z<<(M1_OCTREE_ROOT_BITS*2));
    }
    uint getOctree(ivec3 i) {
        return getOctree(i.x, i.y, i.z);
    }
    void setDField(uint oct, uint x, uint y, uint z) {
        //expect(x<32 && y<32 && z<32);
        //expect(oct<OCTREE_ROOT_INDEXES_LENGTH);

        /// We only have 5 bits per axis
        x = min(31, x);
        y = min(31, y);
        z = min(31, z);

        dfields[oct] = cast(ushort)(x | (y<<5) | (z<<10));
    }
}
//static if(OCTREE_ROOT_BITS==3) {
//    static assert(OptimisedRoot.sizeof==1692);
//} else static if(OCTREE_ROOT_BITS==4) {
    static assert(OptimisedRoot.sizeof==13340);
//}
static assert(OptimisedRoot.bitsAndPopcnts.offsetof%4==0);
static assert(OptimisedRoot.voxels.offsetof%4==0);
static assert(OptimisedRoot.dfields.offsetof%4==0);

///
/// Optimise an edited chunk to a more efficient read-only representation.
///
ubyte[] getOptimisedVoxels(M1ChunkEditView view) {
    numChunksOptimised++;

    view.root.recalculateFlags();

    mergeDuplicateLeaves(view);
    mergeDuplicateBranches(view);

    return convertToReadOptimised(view);
}
private:
///
/// Search for and merge any duplicate leaves together.
///
void mergeDuplicateLeaves(M1ChunkEditView view) {

    auto tup     = getUniqueLeaves(view);
    auto leafMap = tup[1];  // old to new index

    // point to new unique leaves
    view.leaves = tup[0];
    view.freeLeaves.clear();

    // Assuming CHUNK_SIZE_SHR=10 and OCTREE_ROOT_BITS=4:
    // 11_1100_0000  toLevel=6
    //      10_0000  6
    //       1_0000  5
    //         1000  4
    //          100  3
    //           10  2
    //            1  1 leaf
    void recurse(ref OctreeIndex idx, uint toLevel) {
        const pointingToLeaf = toLevel==1;
        const index = idx.offset;

        if(pointingToLeaf) {
            // update the leaf index
            idx.offset = leafMap[index];
        } else {
            auto branch = view.toBranchPtr(index);
            foreach(uint oct, ref idx2; branch.indexes) {
                if(!branch.isSolid(oct)) {
                    recurse(idx2, toLevel-1);
                }
            }
        }
    }
    foreach(uint oct, ref idx; view.root.indexes) {
        if(!view.root.isSolid(oct)) {
            recurse(idx, CHUNK_SIZE_SHR-M1_OCTREE_ROOT_BITS);
        }
    }
    //writefln("Chunk %s unique leaves = %s", view.chunk.pos, view.leaves.length);
}
///
/// Search for and merge any duplicate branches together.
///
void mergeDuplicateBranches(M1ChunkEditView view) {
    // May need equals and hashCode for OctreeBranch and OctreeLeaf.
    // Work from leaf back towards root.

    uint count;
    uint lvl;
    uint[OctreeBranch] map; // value is uint index of branch

    // Assuming CHUNK_SIZE_SHR=10 and OCTREE_ROOT_BITS=4:
    // 11_1100_0000  toLevel=6
    //      10_0000  6
    //       1_0000  5
    //         1000  4
    //          100  3
    //           10  2
    //            1  1 leaf
    void recurseBranch(ref OctreeIndex parentIdx, OctreeBranch* branch, uint level) {
        const pointingToLeaf = level==2;

        if(level==lvl) {
            count++;
            uint* p = *branch in map;
            if(p) {
                parentIdx.offset = *p;
                return;
            } else {
                parentIdx.offset = cast(uint)map.length;
                map[*branch] = cast(uint)map.length;//view.toIndex(branch);
            }
        }

        if(!pointingToLeaf) {
            foreach(uint oct, ref idx; branch.indexes) {
                if(!branch.isSolid(oct)) {
                    recurseBranch(idx, view.toBranchPtr(idx.offset), level-1);
                }
            }
        }
    }

    for(lvl = 2; lvl < 3; lvl++) {
        count = 0;
        map.clear();
        foreach(uint oct, ref idx; view.root.indexes) {
            if(!view.root.isSolid(oct)) {
                recurseBranch(
                    idx,
                    view.toBranchPtr(idx.offset),
                    CHUNK_SIZE_SHR-M1_OCTREE_ROOT_BITS
                );
            }
        }
        //writefln("[%s] %s/%s unique (%.2f%%) level %s branches", view.chunk.pos, map.length, count, (map.length*100.0)/count,lvl);
    }
    // write unique level2 branches to view
    view.l2Branches.length = map.length;
    foreach(k,v; map) {
        expect(v<view.l2Branches.length);
        view.l2Branches[v] = k;
    }
    //writefln("Written %s unique level2 branches", view.l2Branches.length);
}
///
/// Finds all unique leaves and sorts them in order of popularity.
/// (most used at the start of the list).
/// Returns list of unique leaves in order, map of old index to new index.
///
Tuple!(OctreeLeaf[],uint[]) getUniqueLeaves(M1ChunkEditView view) {
    static struct Unique {
        OctreeLeaf leaf;
        uint count;
        Stack!uint indexes;
        this(OctreeLeaf* l) {
            leaf    = *l;
            count   = 1;
            indexes = new Stack!uint(4);
        }
    }
    Unique[ulong] map;

    ulong getKey(OctreeLeaf* l) {
        ulong* p = cast(ulong*)l;
        return *p;
    }
    // Assuming CHUNK_SIZE_SHR=10 and OCTREE_ROOT_BITS=4:
    // 11_1100_0000  toLevel=6
    //      10_0000  6
    //       1_0000  5
    //         1000  4
    //          100  3
    //           10  2
    //            1  1 leaf
    void recurse(ref OctreeIndex idx, uint toLevel) {
        const pointingToLeaf = toLevel==1;
        const index = idx.offset;

        if(pointingToLeaf) {
            auto leaf = view.toLeafPtr(index);
            auto key  = getKey(leaf);
            auto u    = key in map;
            if(u) {
                u.count++;
                u.indexes.push(index);
            } else {
                auto u2 = Unique(leaf);
                u2.indexes.push(index);
                map[key] = u2;
            }
        } else {
            auto branch = view.toBranchPtr(index);
            foreach(uint oct, ref idx2; branch.indexes) {
                if(!branch.isSolid(oct)) {
                    recurse(idx2, toLevel-1);
                }
            }
        }
    }
    foreach(uint oct, ref idx; view.root.indexes) {
        if(!view.root.isSolid(oct)) {
            recurse(idx, CHUNK_SIZE_SHR-M1_OCTREE_ROOT_BITS);
        }
    }

    auto sorted        = map.values.sort!((a,b)=>a.count > b.count).array;
    auto uniqueLeaves  = sorted.map!(it=>it.leaf).array;
    auto oldIndexToNew = new uint[view.leaves.length];

    foreach(i,ref v; sorted) {
        foreach(from; v.indexes[]) {
            oldIndexToNew[from] = i.toInt;
        }
    }
    return tuple(uniqueLeaves,oldIndexToNew);
}
///
/// Convert to compact root.
/// Convert all 25 byte branches to 12 byte twigs.
///
ubyte[] convertToReadOptimised(M1ChunkEditView view) {
    // assume view.leaves has been de-duped

    OctreeTwig[] twigs = new OctreeTwig[view.branches.length+(8^^M1_OCTREE_ROOT_BITS)];
    uint twigIndex;

    OctreeTwig[] l2twigs = new OctreeTwig[view.l2Branches.length];
    ubyte[] l2twigVoxels = new ubyte[l2twigs.length];
    l2twigVoxels[] = 255;
    auto l2Indexes = appender!(ubyte[]);
    uint l2IndexesWritten;
    uint l2EncodeBits = bitsRequiredToEncode(view.l2Branches.length);
    void l2ByteReady(ubyte b) {
        l2Indexes ~= b;
    }
    auto l2IndexBitWriter = new BitWriter(&l2ByteReady);

    auto leafIndexes = appender!(ubyte[]);
    uint leafIndexesWritten;
    uint leafEncodeBits = bitsRequiredToEncode(view.leaves.length);
    void leafByteReady(ubyte b) {
        leafIndexes ~= b;
    }
    auto leafIndexBitWriter = new BitWriter(&leafByteReady);

    ubyte recurseL2Branch(OctreeBranch* branch, uint l2BranchIndex) {
        expect(l2BranchIndex<l2twigVoxels.length);

        if(l2twigVoxels[l2BranchIndex]<255) return l2twigVoxels[l2BranchIndex];

        OctreeTwig* twig = &l2twigs[l2BranchIndex];
        twig.bits = branch.bits;
        twig.setBaseIndex(leafIndexesWritten);

        foreach(uint oct, ref idx; branch.indexes) {
            if(!branch.isSolid(oct)) {

                leafIndexBitWriter.write(idx.offset, leafEncodeBits);
                leafIndexesWritten++;

                twig.voxels[oct] = getAverageVoxel(view.leaves[idx.offset].voxels);
            } else {
                twig.voxels[oct] = branch.getVoxel(oct);
            }
        }
        l2twigVoxels[l2BranchIndex] = getAverageVoxel(twig.voxels);
        return l2twigVoxels[l2BranchIndex];
    }
    ubyte recurseL3Branch(OctreeBranch* branch, const uint ti) {
        twigs[ti].bits = branch.bits;
        twigs[ti].setBaseIndex(l2IndexesWritten);

        foreach(uint oct, ref idx; branch.indexes) {
            if(!branch.isSolid(oct)) {
                auto b = view.toL2BranchPtr(idx.offset);

                l2IndexBitWriter.write(idx.offset, l2EncodeBits);
                l2IndexesWritten++;

                twigs[ti].voxels[oct] = recurseL2Branch(b, idx.offset);
            } else {
                twigs[ti].voxels[oct] = branch.getVoxel(oct);
            }
        }
        return getAverageVoxel(twigs[ti].voxels);
    }
    // Assuming CHUNK_SIZE_SHR=10 and OCTREE_ROOT_BITS=4:
    //    100_0000  7
    //     10_0000  6
    //      1_0000  5
    //        1000  4
    //         100  3
    //          10  2
    //           1  1 leaf
    ubyte recurseBranch(OctreeBranch* branch, const uint ti, uint level) {
        // write this twig
        twigs[ti].bits = branch.bits;
        twigs[ti].setBaseIndex(twigIndex);

        auto numSubBranches = branch.numOffsets;

        uint ti2 = twigIndex;
        twigIndex += numSubBranches;

        foreach(uint oct, ref idx; branch.indexes) {
            if(!branch.isSolid(oct)) {
                auto b = view.toBranchPtr(idx.offset);
                ubyte lodvox;
                if(level==4) {
                    lodvox = recurseL3Branch(b, ti2++);
                } else {
                    lodvox = recurseBranch(b, ti2++, level-1);
                }
                twigs[ti].voxels[oct] = lodvox;
            } else {
                twigs[ti].voxels[oct] = branch.getVoxel(oct);
            }
        }
        return getAverageVoxel(twigs[ti].voxels);
    }
    //===============================================================

    auto initialVoxelsLength = max(view.voxelsLength, OptimisedRoot.sizeof);
    auto voxels         = uninitializedArray!(ubyte[])(initialVoxelsLength);
    OptimisedRoot* root = cast(OptimisedRoot*)voxels.ptr;

    uint tindex = 0;
    twigIndex  += view.root.numOffsets();

    foreach(uint oct, ref idx; view.root.indexes) {
        if(!view.root.isSolid(oct)) {
            auto b = view.toBranchPtr(idx.offset);
            ubyte lodvox = recurseBranch(b, tindex, CHUNK_SIZE_SHR-M1_OCTREE_ROOT_BITS);

            root.voxels[oct] = lodvox;
            tindex++;
        } else {
            root.voxels[oct] = view.root.getVoxel(oct);
        }
        root.setDField(oct, 0,0,0);
    }
    l2IndexBitWriter.flush();
    leafIndexBitWriter.flush();
    while((l2Indexes.data.length&3)!=0) l2IndexBitWriter.write(0, 8);
    while((leafIndexes.data.length&3)!=0) leafIndexBitWriter.write(0, 8);

//    writefln("num twigs = %s", twigIndex);
//    writefln("num l2twigs = %s", l2twigs.length);
//    writefln("l2Index bytes = %s", l2Indexes.data.length);
//    writefln("leafIndex bytes = %s", leafIndexes.data.length);

    root.flags           = view.root.flags;
    root.twigsOffset     = OptimisedRoot.sizeof;
    root.l2TwigsOffset   = root.twigsOffset + cast(uint)(twigIndex*OctreeTwig.sizeof);
    root.leavesOffset    = root.l2TwigsOffset + cast(uint)(l2twigs.length*OctreeTwig.sizeof);
    root.l2IndexOffset   = root.leavesOffset + cast(uint)(view.leaves.length*OctreeLeaf.sizeof);
    root.leafIndexOffset = root.l2IndexOffset + cast(uint)(l2Indexes.data.length);
    root.encodeBits      = (leafEncodeBits | (l2EncodeBits<<8));

    expect(root.twigsOffset%4==0);
    expect(root.l2TwigsOffset%4==0);
    expect(root.leavesOffset%4==0);
    expect(root.l2IndexOffset%4==0);
    expect(root.leafIndexOffset%4==0);

    // realloc to the real required length
    voxels.length = root.leafIndexOffset + leafIndexes.data.length;

    // make sure we are still pointing to the root
    root = cast(OptimisedRoot*)voxels.ptr;

    // Copy bits and calculate popcnts
    ushort* bitsPtr = cast(ushort*)view.root.bits.ptr;
    uint bctotal = 0;
    for(auto i=0; i<root.bitsAndPopcnts.length; i++) {
        uint bits = bitsPtr[i];
        uint pop  = bctotal;
        root.bitsAndPopcnts[i] = bits | (pop<<16);

        bctotal += popcnt(bits);
    }

    // twigs
    memcpy(voxels.ptr+root.twigsOffset, twigs.ptr, twigIndex*OctreeTwig.sizeof);
    // l2twigs
    memcpy(voxels.ptr+root.l2TwigsOffset, l2twigs.ptr, l2twigs.length*OctreeTwig.sizeof);
    // leaves
    memcpy(voxels.ptr+root.leavesOffset, view.leaves.ptr, view.leaves.length*OctreeLeaf.sizeof);
    // l2twig indexes
    memcpy(voxels.ptr+root.l2IndexOffset, l2Indexes.data.ptr, l2Indexes.data.length);
    // leaf indexes
    memcpy(voxels.ptr+root.leafIndexOffset, leafIndexes.data.ptr, leafIndexes.data.length);

    //writefln("written %s bytes to voxels", voxels.length);

    if(twigIndex>maxBranches) maxBranches = twigIndex;
    if(view.leaves.length>maxLeaves) maxLeaves = view.leaves.length;
    if(voxels.length>maxVoxelsLength) maxVoxelsLength = voxels.length;
    return voxels;
}