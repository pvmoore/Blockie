module blockie.model3.M3Optimiser;

/**
 *  Convert edit-optimised voxels into render-optimised voxels.
 */
import blockie.all;

final class M3Optimiser {
private:
    M3ChunkEditView view;
    ubyte[] voxels;
    uint voxelsLength;
    uint[uint] branchTranslations;
public:
    this(M3ChunkEditView view) {
        this.view = view;
    }
    ubyte[] optimise(ubyte[] voxels, uint voxelsLength) {
        this.voxels       = voxels;
        this.voxelsLength = voxelsLength;

        if(view.isAir) {
            return cast(ubyte[])[M3Flag.AIR, 0] ~ view.root().distance.toBytes();
        }

        branchTranslations.clear();

        writefln("Optimising %s\n\tStart voxels length        = %s", view.getChunk.pos, voxelsLength);

        mergeUniqueLeaves();
        mergeUniqueBranches(3);
        mergeUniqueBranches(4);

        auto optVoxels = rewriteVoxels();

        writefln("\toptimised %s --> %s (%.2f%%)",
            voxelsLength, optVoxels.length, optVoxels.length*100.0 / voxelsLength);

        return optVoxels;
    }
private:
    M3Root* getRoot() { return cast(M3Root*)voxels.ptr; }

    void mergeUniqueBranches(uint theLevel) {

        static struct Key {
            ubyte bits;
            M3Branch[8] branches;

            this(ubyte* base, M3Branch* br) {
                bits = br.bits;

                auto ptr = cast(M3Branch*)(base+(br.offset.get()*4));
                for(auto i=0; i<8; i++) {
                    if(br.isBranch(i)) {
                        branches[i] = *ptr;
                    }
                    ptr++;
                }
            }
        }

        uint[Key] map;
        uint numBranches;

        // 11_1110_0000  5 M3Cell   --> point to 1..8 M3Branch
        //       1_0000  4 M3Branch --> point to 1..8 M3Branch
        //         1000  3 M3Branch --> point to 1..8 M3Branch
        //          100  2 M3Branch --> point to 1..8 M3Leaf
        //           10  1 M3Leaf
        //            1  0

        void recurseBranch(M3Branch* br, uint oct, int level) {
            if(level==theLevel) {
                if(br.isMixed) {
                    numBranches++;

                    auto key    = Key(voxels.ptr, br);
                    uint offset = cast(uint)(cast(ulong)br-cast(ulong)voxels.ptr);

                    auto p = key in map;
                    if(p) {
                        branchTranslations[offset] = *p;

                        /// Replace br with orig
                        uint* src  = cast(uint*)(cast(ulong)voxels.ptr + *p);
                        uint* dest = cast(uint*)br;

                        *dest = *src;
                    } else {
                        map[key] = offset;
                        assert(!(offset in branchTranslations));
                        branchTranslations[offset] = offset;
                    }
                }
            } else if(br.isMixed) {
                for(auto i=0; i<8; i++) {
                    if(br.isBranch(i)) {
                        recurseBranch(br.getBranch(voxels.ptr, i), i, level-1);
                    }
                }
            }
        }
        void recurseCell(M3Cell* cell) {
            if(cell.isMixed) {
                for(auto i=0; i<8; i++) {
                    if(cell.isBranch(i)) {
                        recurseBranch(cell.getBranch(voxels.ptr, i), i, 4);
                    }
                }
            }
        }

        auto cellPtr = cast(M3Cell*)(voxels.ptr+8);
        for(auto i=0; i<M3_CELLS_PER_CHUNK; i++) {
            recurseCell(cellPtr++);
        }

        //writefln("Num mixed L%s branches = %s", theLevel, numBranches);
        //writefln("Num unique = %s", map.length);
    }
    void mergeUniqueLeaves() {
        // 11_1110_0000  5 M3Cell   --> point to 1..8 M3Branch
        //       1_0000  4 M3Branch --> point to 1..8 M3Branch
        //         1000  3 M3Branch --> point to 1..8 M3Branch
        //          100  2 M3Branch --> point to 1..8 M3Leaf
        //           10  1 M3Leaf
        //            1  0

        uint[ulong] map;
        uint numLeaves;

        uint hash(M3Branch* br) {
            numLeaves++;
            ulong n;
            for(auto i=0; i<8; i++) {
                if(br.isBranch(i)) {
                    n |= br.getLeaf(voxels.ptr, i).bits;
                }
                n <<= 8;
            }
            uint offset = cast(uint)(cast(ulong)br-cast(ulong)voxels.ptr);
            auto p = n in map;
            if(!p) {
                map[n] = offset;
                branchTranslations[offset] = offset;
                return 0;
            }
            branchTranslations[offset] = *p;
            return *p;
        }

        void recurseBranch(M3Branch* br, uint oct, int level) {
            if(level==2) {
                if(br.isMixed) {
                    uint offset = hash(br);
                    if(offset > 0) {
                        /// Replace br with orig
                        uint* src  = cast(uint*)(voxels.ptr+offset);
                        uint* dest = cast(uint*)br;

                        *dest = *src;
                    }
                }
            } else if(br.isMixed) {
                for(auto i=0; i<8; i++) {
                    if(br.isBranch(i)) {
                        recurseBranch(br.getBranch(voxels.ptr, i), i, level-1);
                    }
                }
            }
        }
        void recurseCell(M3Cell* cell) {
            if(cell.isMixed) {
                for(auto i=0; i<8; i++) {
                    if(cell.isBranch(i)) {
                        recurseBranch(cell.getBranch(voxels.ptr, i), i, 4);
                    }
                }
            }
        }

        auto cellPtr = cast(M3Cell*)(voxels.ptr+8);
        for(auto i=0; i<M3_CELLS_PER_CHUNK; i++) {
            recurseCell(cellPtr++);
        }

        //writefln("num mixed leaves = %s", numLeaves);
        //writefln("num unique mixed = %s", map.length);
        //foreach(k,v; map) {
        //    //writefln("%08x = %s", k, v);
        //}
    }
    ///
    ///
    ///
    ubyte[] rewriteVoxels() {
        ubyte[] newVoxels = new ubyte[voxelsLength];
        uint dest         = M3Root.sizeof;

        uint count;

        M3Branch*[uint] oldToNew;

        M3Branch* translate(M3Branch* oldBr, M3Branch* newBr) {
            uint oldFrom = cast(uint)(cast(ulong)oldBr - cast(ulong)voxels.ptr);
            auto p = oldFrom in branchTranslations;
            if(p) {
                uint oldTo = *p;
                if(oldFrom==oldTo) {
                    assert(!(oldTo in oldToNew));
                    oldToNew[oldTo] = newBr;
                    return null;
                }
                return oldToNew[oldTo];
            }
            return null;
        }

        // 11_1110_0000  5 M3Cell   --> point to 1..8 M3Branch
        //       1_0000  4 M3Branch --> point to 1..8 M3Branch
        //         1000  3 M3Branch --> point to 1..8 M3Branch
        //          100  2 M3Branch --> point to 1..8 M3Leaf
        //           10  1 M3Leaf
        //            1  0
        void recurseLeaf(M3Leaf* oldLeaf, M3Leaf* newLeaf) {
            newLeaf.bits = oldLeaf.bits;
        }
        void recurseBranch(M3Branch* oldBr, M3Branch* newBr, uint oct, int level) {

            newBr.bits = oldBr.bits;

            if(oldBr.isSolid) {
                newBr.offset.set(0xffffff);
            } else if(oldBr.isAir) {
                newBr.offset.set(0);
            } else {
                /// Drill down

                auto t = translate(oldBr, newBr);
                if(t) {
                    count+=oldBr.numBranches;
                    newBr.offset.set(t.offset.get());
                    return;
                }

                assert(dest%4==0);
                newBr.offset.set(dest/4);

                if(level==2) {
                    dest += oldBr.numBranches() * 1;
                    dest = (dest+3) & 0xffff_fffc;  /// Align to 4 bytes

                    auto oldLeaves = cast(M3Leaf*)(voxels.ptr    + oldBr.offset.get()*4);
                    auto newLeaves = cast(M3Leaf*)(newVoxels.ptr + newBr.offset.get()*4);

                    for(auto i=0; i<8; i++) {
                        if(oldBr.isBranch(i)) {
                            recurseLeaf(oldLeaves, newLeaves);
                            newLeaves++;
                        }
                        oldLeaves++;
                    }
                } else {
                    dest += oldBr.numBranches() * 4;

                    auto oldBranches = cast(M3Branch*)(voxels.ptr    + oldBr.offset.get()*4);
                    auto newBranches = cast(M3Branch*)(newVoxels.ptr + newBr.offset.get()*4);

                    for(auto i=0; i<8; i++) {
                        if(oldBr.isBranch(i)) {

                            recurseBranch(oldBranches, newBranches, i, level-1);
                            newBranches++;
                        }
                        oldBranches++;
                    }
                }
            }
        }
        void recurseCell(M3Cell* oldCell, M3Cell* newCell) {
            /// Cell contents have already been copied.
            /// We just need to adjust the base offsets
            if(oldCell.isMixed) {
                newCell.offset.set(dest/4);
                dest += oldCell.numBranches() * 4;

                auto oldBranches = cast(M3Branch*)(voxels.ptr    + oldCell.offset.get()*4);
                auto newBranches = cast(M3Branch*)(newVoxels.ptr + newCell.offset.get()*4);

                for(auto i=0; i<8; i++) {
                    if(oldCell.isBranch(i)) {
                        recurseBranch(oldBranches, newBranches, i, 4);
                        newBranches++;
                    }
                    oldBranches++;
                }
            }
        }

        //writefln("Rewriting voxels ...");
        //writefln("Got %s branchTranslations", branchTranslations.length);

        /// Copy the root
        newVoxels[0..dest] = voxels[0..dest];

        /// Recurse through the cells, updating the offsets
        auto oldCells = cast(M3Cell*)(voxels.ptr+8);
        auto newCells = cast(M3Cell*)(newVoxels.ptr+8);
        for(auto i=0; i<M3_CELLS_PER_CHUNK; i++) {
            recurseCell(oldCells++, newCells++);
        }

        return newVoxels[0..dest];
    }
    ///
    /// Standard Root:
    ///     ubyte flag                  (1 byte)
    ///     M3Distance chunkDistances   (3 bytes)
    ///     M3Cell[32768] cells         (32768*4 bytes) -> will need to be 7 bytes per cell
    /// [131076 bytes]
    ///     ... octrees
    ///
    /// Optimised Root:

    ///     ubyte[4096] flags       (1 bit per cell -> 4096 bytes)
    ///     uint[1024] popcounts    (4096 bytes)
    ///     uint numUniqDistances   (4 bytes)
    ///     uint bitsPerDistancePtr (4 bytes)
    ///     uint bitsPerOctreePtr   (4 bytes)
    ///
    ///     ++implied NUM_DISTANCE_PTRS = 32768-popcount[1023]
    ///               NUM_OCTREE_PTRS   = popcounts[1023]
    ///
    ///     ++offsets A = 4096+4096+4+4+4
    ///               B = A + (numUniqDistances * bitsPerDistancePtr) (rounded up to next byte)
    ///               C = B + (NUM_DISTANCE_PTRS * bitsPerDistancePtr) (rounded up to next byte)
    ///
    /// [A] ubyte[] uniqDistances  6*numUniqDistances bytes
    /// [B] ubyte[] distancePtrs   bitsPerDistancePtr bits * NUM_DISTANCE_PTRS
    /// [C] ubyte[] octreePtrs     bitsPerOctreePtr bits   * NUM_OCTREE_PTRS
    ///
    ///     ... octrees
    /*
    ubyte[] rewriteVoxels2(ubyte[] srcVoxels) {
        writefln("\tIntermediate voxels length = %s", srcVoxels.length);


        M3Root* srcRoot() { return cast(M3Root*)srcVoxels.ptr; }

        ubyte[] newVoxels = new ubyte[srcVoxels.length];
        uint dest         = 0;

        /// Write flag and chunk distances
        newVoxels[0..4] = srcVoxels[0..4];
        dest = 4;

        /// Write flag bits and pop counts and generate unique cell distances
        uint[Distance6] uniqDistancesMap;
        uint numDistances;
        uint numOctreePtrs;

        void writeByte(ubyte b) {
            newVoxels[dest++] = b;
        }
        auto writer = new BitWriter(&writeByte);
        //writer.write(1, 1);

        foreach(cell; srcRoot().cells) {
            if(cell.isAir) {
                numDistances++;
                uniqDistancesMap[cell.distance]++;

            } else {
                numOctreePtrs++;
            }
        }
        auto uniqDistances      = uniqDistancesMap.keys;
        uint bitsPerDistancePtr = bitsRequiredToEncode(uniqDistances.length);
        uint bitsPerOctreePtr   = bitsRequiredToEncode(numOctreePtrs);

        writefln("\tnum distances      = %s", numDistances);
        writefln("\tnum octree ptrs    = %s", numOctreePtrs);
        writefln("\tunique distances   = %s", uniqDistances.length);
        writefln("\tbitsPerDistancePtr = %s", bitsPerDistancePtr);
        writefln("\tbitsPerOctreePtr   = %s", bitsPerOctreePtr);

        //void recurseLeaf(M3Leaf* srcLeaf, M3Leaf* destLeaf) {
        //
        //}
        void recurseBranch(M3Branch* srcBranch, M3Branch* destBranch) {

        }
        void recurseCell(M3Cell* srcCell, M3Cell* destCell) {

        }

        /// Update cell octree ptrs
        foreach(cell; srcRoot().cells) {
            if(cell.isAir) {

            } else {

            }
        }

        return srcVoxels;
    }
    */
}