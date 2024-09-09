module blockie.model2.M2Optimiser;

import blockie.model;

/**
 *
 *
 *
 *
 *
 *
 *
 *
 *
 *
 *
 *  
 */
final class M2Optimiser : Optimiser {
private:
    M2ChunkEditView view;
    ubyte[] voxels;
    uint voxelsLength;
    uint[uint] branchTranslations;
public:
    this(M2ChunkEditView view) {
        this.view = view;
    }
    override ubyte[] optimise(ubyte[] voxels, uint voxelsLength) {
        this.voxels       = voxels;
        this.voxelsLength = voxelsLength;

        if(view.isAir) {
            return cast(ubyte[])[M2Flag.AIR, 0] ~ view.root().distance.toBytes();
        }

        branchTranslations.clear();

        mergeUniqueLeaves();
        mergeUniqueBranches(3);
        mergeUniqueBranches(4);
        mergeUniqueBranches(5);

        auto optVoxels = rewriteVoxels();

        writefln("Optimised chunk %s %s --> %s (%.2f%%)", view.getChunk.pos,
            voxelsLength, optVoxels.length, optVoxels.length*100.0 / voxelsLength);

        return optVoxels;
    }
private:
    M2Root* getRoot() { return cast(M2Root*)voxels.ptr; }

    void mergeUniqueBranches(uint theLevel) {

        static struct Key {
            ubyte bits;
            M2Branch[8] branches;

            this(ubyte* base, M2Branch* br) {
                bits = br.bits;

                auto ptr = cast(M2Branch*)(base+(br.offset.get()*4));
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

        // 11_1100_0000  6 M2Cell   --> point to 1..8 M2Branch
        //      10_0000  5 M2Branch --> point to 1..8 M2Branch
        //       1_0000  4 M2Branch --> point to 1..8 M2Branch
        //         1000  3 M2Branch --> point to 1..8 M2Branch
        //          100  2 M2Branch --> point to 1..8 M2Leaf
        //           10  1 M2Leaf
        //            1  0

        void recurseBranch(M2Branch* br, uint oct, int level) {
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
        void recurseCell(M2Cell* cell) {
            if(cell.isMixed) {
                for(auto i=0; i<8; i++) {
                    if(cell.isBranch(i)) {
                        recurseBranch(cell.getBranch(voxels.ptr, i), i, 5);
                    }
                }
            }
        }

        auto cellPtr = cast(M2Cell*)(voxels.ptr+8);
        for(auto i=0; i<M2_CELLS_PER_CHUNK; i++) {
            recurseCell(cellPtr++);
        }

        writefln("mergeUniqueBranches(%s) :", theLevel);
        writefln("  Num mixed L%s branches = %s", theLevel, numBranches);
        writefln("  Num unique = %s", map.length);
    }
    void mergeUniqueLeaves() {
        // 11_1100_0000  6 M2Cell   --> point to 1..8 M2Branch
        //      10_0000  5 M2Branch --> point to 1..8 M2Branch
        //       1_0000  4 M2Branch --> point to 1..8 M2Branch
        //         1000  3 M2Branch --> point to 1..8 M2Branch
        //          100  2 M2Branch --> point to 1..8 M2Leaf
        //           10  1 M2Leaf
        //            1  0

        uint[ulong] map;
        uint numLeaves;

        uint hash(M2Branch* br) {
            numLeaves++;
            ulong n;
            for(auto i=0; i<8; i++) {
                 n <<= 8;
                if(br.isBranch(i)) {
                    n |= br.getLeaf(voxels.ptr, i).bits;
                }
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

        void recurseBranch(M2Branch* br, uint oct, int level) {
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
        void recurseCell(M2Cell* cell) {
            if(cell.isMixed) {
                for(auto i=0; i<8; i++) {
                    if(cell.isBranch(i)) {
                        recurseBranch(cell.getBranch(voxels.ptr, i), i, 5);
                    }
                }
            }
        }

        auto cellPtr = cast(M2Cell*)(voxels.ptr+8);
        for(auto i=0; i<M2_CELLS_PER_CHUNK; i++) {
            recurseCell(cellPtr++);
        }

        writefln("mergeUniqueLeaves:");
        writefln("  num mixed leaves = %s", numLeaves);
        writefln("  num unique mixed = %s", map.length);
        //foreach(k,v; map) {
        //    //writefln("%08x = %s", k, v);
        //}
    }
    ///
    ///
    ///
    ubyte[] rewriteVoxels() {
        ubyte[] newVoxels = new ubyte[voxelsLength];
        uint dest         = M2Root.sizeof;

        uint count;

        M2Branch*[uint] oldToNew;

        M2Branch* translate(M2Branch* oldBr, M2Branch* newBr) {
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

        // 11_1100_0000  6 M2Cell   --> point to 1..8 M2Branch
        //      10_0000  5 M2Branch --> point to 1..8 M2Branch
        //       1_0000  4 M2Branch --> point to 1..8 M2Branch
        //         1000  3 M2Branch --> point to 1..8 M2Branch
        //          100  2 M2Branch --> point to 1..8 M2Leaf
        //           10  1 M2Leaf
        //            1  0
        void recurseLeaf(M2Leaf* oldLeaf, M2Leaf* newLeaf) {
            newLeaf.bits = oldLeaf.bits;
        }
        // Branch :
        // 
        // bits   - 1 byte
        // offset - 3 bytes (0xffffff if solid)
        //
        void recurseBranch(M2Branch* oldBr, M2Branch* newBr, uint oct, int level) {

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

                    auto oldLeaves = cast(M2Leaf*)(voxels.ptr    + oldBr.offset.get()*4);
                    auto newLeaves = cast(M2Leaf*)(newVoxels.ptr + newBr.offset.get()*4);

                    for(auto i=0; i<8; i++) {
                        if(oldBr.isBranch(i)) {
                            recurseLeaf(oldLeaves, newLeaves);
                            newLeaves++;
                        }
                        oldLeaves++;
                    }
                } else {
                    dest += oldBr.numBranches() * 4;

                    auto oldBranches = cast(M2Branch*)(voxels.ptr    + oldBr.offset.get()*4);
                    auto newBranches = cast(M2Branch*)(newVoxels.ptr + newBr.offset.get()*4);

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
        // M2Cell { // (4 bytes)
        //   ubyte bits;
        //   union {
        //     Distance3 distance; 
        //     Offset3 offset;
        //   }    
        // }
        void recurseCell(M2Cell* oldCell, M2Cell* newCell) {
            /// Cell contents have already been copied.
            /// We just need to adjust the base offsets
            if(oldCell.isMixed) {
                newCell.offset.set(dest/4);
                dest += oldCell.numBranches() * 4;

                auto oldBranches = cast(M2Branch*)(voxels.ptr    + oldCell.offset.get()*4);
                auto newBranches = cast(M2Branch*)(newVoxels.ptr + newCell.offset.get()*4);

                for(auto i=0; i<8; i++) {
                    if(oldCell.isBranch(i)) {
                        recurseBranch(oldBranches, newBranches, i, 5);
                        newBranches++;
                    }
                    oldBranches++;
                }
            }
        }

        writefln("Rewriting voxels ...");
        writefln("Got %s branchTranslations", branchTranslations.length);

        // [0] M2Root { // 8 + 16384 bytes
        //   M2Flag flag;
        //   byte _reserved;
        //   Distance6 distance;   
        // } 
        // [8] M2Cell[4096] cells; (4096*4 = 16384 bytes)

        /// Copy the root
        newVoxels[0..dest] = voxels[0..dest];

        

        /// Recurse through the cells, updating the offsets
        auto oldCells = cast(M2Cell*)(voxels.ptr+8);
        auto newCells = cast(M2Cell*)(newVoxels.ptr+8);
        for(auto i=0; i<M2_CELLS_PER_CHUNK; i++) {
            recurseCell(oldCells++, newCells++);
        }

        //writefln("Dest=%s", dest);
        //writefln("count=%s", count);

        return newVoxels[0..dest];
    }
}
