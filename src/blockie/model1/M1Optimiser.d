module blockie.model1.M1Optimiser;

import blockie.model;
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
 *      uint    encodeBits (leafEncodeBits | (l2EncodeBits<<8))
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

__gshared ulong maxBranches;
__gshared ulong maxLeaves;
__gshared ulong maxVoxelsLength;

final class M1Optimiser {
private:
    M1ChunkEditView view;
public:
    this(M1ChunkEditView view) {
        this.view = view;
    }
    ubyte[] optimise() {

        view.root.recalculateFlags();

        if(view.isAir) {
            return cast(ubyte[])[OctreeFlag.AIR, 0] ~ view.root.flags.distance.toBytes();
        }

        auto originalSize = view.voxelsLength;

        mergeDuplicateLeaves();
        mergeDuplicateBranches();

        auto optVoxels = convertToReadOptimised();

        writefln("Optimised chunk %s %s --> %s (%.2f%%)", view.getChunk.pos,
            originalSize, optVoxels.length, optVoxels.length*100.0 / originalSize);

        //writefln("\tmaxBranches     = %s", maxBranches);
        //writefln("\tmaxLeaves       = %s (%s bits)", maxLeaves, bitsRequiredToEncode(maxLeaves));
        //writefln("\tmaxVoxelsLength = %s", maxVoxelsLength);

        return optVoxels;
    }
private:
    ///
    /// Finds all unique leaves and sorts them in order of popularity.
    /// (most used at the start of the list).
    /// Returns list of unique leaves in order, map of old index to new index.
    ///
    Tuple!(OctreeLeaf[],uint[]) getUniqueLeaves() {
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
                    if(!branch.isSolidAt(oct)) {
                        recurse(idx2, toLevel-1);
                    }
                }
            }
        }
        foreach(uint oct, ref idx; view.root.indexes) {
            if(!view.root.isSolidCell(oct)) {
                recurse(idx, CHUNK_SIZE_SHR-M1_OCTREE_ROOT_BITS);
            }
        }

        auto sorted        = map.values.sort!((a,b)=>a.count > b.count).array;
        auto uniqueLeaves  = sorted.map!(it=>it.leaf).array;
        auto oldIndexToNew = new uint[view.leaves.length];

        foreach(i,ref v; sorted) {
            foreach(from; v.indexes[]) {
                oldIndexToNew[from] = i.as!int;
            }
        }
        return tuple(uniqueLeaves,oldIndexToNew);
    }
    ///
    /// Search for and merge any duplicate leaves together.
    ///
    void mergeDuplicateLeaves() {

        auto tup     = getUniqueLeaves();
        auto leafMap = tup[1];  // old to new index

        // point to new unique leaves
        view.leaves = tup[0];
        view.freeLeaves.clear();

        // CHUNK_SIZE_SHR=10 and OCTREE_ROOT_BITS=4:
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
                    if(!branch.isSolidAt(oct)) {
                        recurse(idx2, toLevel-1);
                    }
                }
            }
        }
        foreach(uint oct, ref idx; view.root.indexes) {
            if(!view.root.isSolidCell(oct)) {
                recurse(idx, CHUNK_SIZE_SHR-M1_OCTREE_ROOT_BITS);
            }
        }
        //writefln("Chunk %s unique leaves = %s", view.chunk.pos, view.leaves.length);
    }
    ///
    /// Search for and merge any duplicate branches together.
    ///
    void mergeDuplicateBranches() {
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
                    if(!branch.isSolidAt(oct)) {
                        recurseBranch(idx, view.toBranchPtr(idx.offset), level-1);
                    }
                }
            }
        }

        for(lvl = 2; lvl < 3; lvl++) {
            count = 0;
            map.clear();
            foreach(uint oct, ref idx; view.root.indexes) {
                if(!view.root.isSolidCell(oct)) {
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
    /// Convert to compact root.
    /// Convert all 25 byte branches to 12 byte twigs.
    ///
    ubyte[] convertToReadOptimised() {
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
                if(!branch.isSolidAt(oct)) {

                    leafIndexBitWriter.write(idx.offset, leafEncodeBits);
                    leafIndexesWritten++;

                    twig.voxels[oct] = getAverageVoxel(view.leaves[idx.offset].voxels);
                } else {
                    twig.voxels[oct] = branch.getVoxelAt(oct);
                }
            }
            l2twigVoxels[l2BranchIndex] = getAverageVoxel(twig.voxels);
            return l2twigVoxels[l2BranchIndex];
        }
        ubyte recurseL3Branch(OctreeBranch* branch, const uint ti) {
            twigs[ti].bits = branch.bits;
            twigs[ti].setBaseIndex(l2IndexesWritten);

            foreach(uint oct, ref idx; branch.indexes) {
                if(!branch.isSolidAt(oct)) {
                    auto b = view.toL2BranchPtr(idx.offset);

                    l2IndexBitWriter.write(idx.offset, l2EncodeBits);
                    l2IndexesWritten++;

                    twigs[ti].voxels[oct] = recurseL2Branch(b, idx.offset);
                } else {
                    twigs[ti].voxels[oct] = branch.getVoxelAt(oct);
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
                if(!branch.isSolidAt(oct)) {
                    auto b = view.toBranchPtr(idx.offset);
                    ubyte lodvox;
                    if(level==4) {
                        lodvox = recurseL3Branch(b, ti2++);
                    } else {
                        lodvox = recurseBranch(b, ti2++, level-1);
                    }
                    twigs[ti].voxels[oct] = lodvox;
                } else {
                    twigs[ti].voxels[oct] = branch.getVoxelAt(oct);
                }
            }
            return getAverageVoxel(twigs[ti].voxels);
        }
        //===============================================================

        auto initialVoxelsLength = max(view.voxelsLength, OptimisedRoot.sizeof);
        auto voxels              = new ubyte[initialVoxelsLength];
        OptimisedRoot* root      = cast(OptimisedRoot*)voxels.ptr;

        uint tindex = 0;
        twigIndex  += view.root.numOffsets();

        foreach(uint oct, ref idx; view.root.indexes) {
            if(!view.root.isSolidCell(oct)) {
                /// Points to an octree
                auto b       = view.toBranchPtr(idx.offset);
                ubyte lodvox = recurseBranch(b, tindex, CHUNK_SIZE_SHR-M1_OCTREE_ROOT_BITS);

                root.voxels[oct] = lodvox;
                tindex++;
            } else {
                /// Solid cell
                root.voxels[oct] = view.root.getVoxel(oct);

                if(view.root.isAirCell(oct)) {
                    auto d = view.root.cellDistances[oct];
                    root.setDField(oct, d.x, d.y, d.z);
                }
            }
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
}