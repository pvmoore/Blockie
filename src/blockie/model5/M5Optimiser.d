module blockie.model5.M5Optimiser;

import blockie.all;

final class M5Optimiser : Optimiser {
private:
    M5ChunkEditView view;
    ubyte[] voxels;
    uint voxelsLength;

    uint[uint] oldToNewOffset;
public:
    this(M5ChunkEditView view) {
        this.view = view;
    }
    override ubyte[] optimise(ubyte[] voxels, uint voxelsLength) {
        this.voxels       = voxels;
        this.voxelsLength = voxelsLength;

        if(view.isAir) {
            return cast(ubyte[])[M5Flag.AIR, 0] ~ view.root().distance.toBytes();
        }

        writefln("Optimising %s\n\tStart voxels length        = %s", view.getChunk.pos, voxelsLength);

        collectUniqCell3s();

        auto optVoxels = rewriteVoxels();

        writefln("\toptimised %s --> %s (%.2f%%)",
            voxelsLength, optVoxels.length, optVoxels.length*100.0 / voxelsLength);

        return optVoxels;
    }
private:
    void collectUniqCell3s() {

        static struct M5SubCell2Key {
            ulong bits;
            uint[64] offsets;

            this(ubyte* base, M5SubCell2* cell) {
                bits = cell.bits;

                auto ptr = cast(M5SubCell3*)(base+(cell.offset.get()*4));
                for(auto i=0; i<64; i++) {
                    if(cell.isBranch(i)) {
                        offsets[i] = ptr.offset.get();
                    }
                    ptr++;
                }
            }
        }

        uint numLeaves;
        uint numCell2s;
        uint[ulong] uniqCell3s;
        uint[M5SubCell2Key] uniqCell2s;

        void _recurseSubCell3(M5SubCell3* cell) {
            if(!cell.isAir && !cell.isSolid) {
                numLeaves++;
                auto offset = cell.offset.get();
                auto value  = cell.getAllLeafBits(voxels.ptr);
                auto p      = value in uniqCell3s;
                if(!p) {
                    uniqCell3s[value] = offset;
                    oldToNewOffset[offset] = 0;
                } else {
                    // Point to the original
                    cell.offset.set(*p);
                }
            }
        }
        void _recurseSubCell2(M5SubCell2* cell) {
            if(!cell.isAir && !cell.isSolid) {
                for(auto i=0; i<64; i++) {
                    if(cell.isBranch(i)) {
                        _recurseSubCell3(cell.getCell(voxels.ptr, i));
                    }
                }

                // Check for duplicate M5SubCell2s
                numCell2s++;
                auto offset = cell.offset.get();
                auto value = M5SubCell2Key(voxels.ptr, cell);
                auto p = value in uniqCell2s;
                if(!p) {
                     uniqCell2s[value] = offset;
                     oldToNewOffset[offset] = 0;
                } else {
                    // Point to the original
                    cell.offset.set(*p);
                }  
            }
        }
        void _recurseSubCell1(M5SubCell1* cell) {
            if(!cell.isAir && !cell.isSolid) {
                for(auto i=0; i<64; i++) {
                    if(cell.isBranch(i)) {
                        _recurseSubCell2(cell.getCell(voxels.ptr, i));
                    }
                }
            }
        }

        auto oldCells = cast(M5SubCell1*)(voxels.ptr+8);

        for(auto i=0; i<M5_CELLS_PER_CHUNK; i++) {
            _recurseSubCell1(oldCells++);
        }

        writefln("numLeaves  = %s, uniq = %s", numLeaves, uniqCell3s.length);
        writefln("uniqCell2s = %s, uniq = %s", numCell2s, uniqCell2s.length);
    }

    ubyte[] rewriteVoxels() {
        ubyte[] newVoxels = new ubyte[voxelsLength];
        uint dest         = M5Root.sizeof;

        void _recurseLeaf(M5Leaf* oldLeaf, M5Leaf* newLeaf) {
            newLeaf.bits = oldLeaf.bits;
        }

        void _recurseSubCell3(M5SubCell3* oldCell, M5SubCell3* newCell) {
            newCell.bits = oldCell.bits;

            if(oldCell.isSolid) {
                newCell.offset.set(0xffff_ffff);
            } else if(oldCell.isAir) {
                newCell.offset.set(0);
            } else {
                
                uint oldOffset = oldCell.offset.get();
                auto p = oldOffset in oldToNewOffset;
                if(p) {
                    if(*p==0) {
                        // This is the original. Set the new offset and continue
                        oldToNewOffset[oldOffset] = dest/4;
                    } else {
                        // This is a duplicate
                        newCell.offset.set(oldToNewOffset[oldOffset]);
                        return;
                    }
                }

                // No duplicate found. Encode this one as normal

                newCell.offset.set(dest/4);

                dest += oldCell.numBranches() * M5Leaf.sizeof;
                dest = (dest+3) & 0xffff_fffc;  // Align to 4 bytes

                ASSERT(dest%4==0);

                auto oldLeaves = cast(M5Leaf*)(voxels.ptr    + oldCell.offset.get()*4);
                auto newLeaves = cast(M5Leaf*)(newVoxels.ptr + newCell.offset.get()*4);

                for(auto i=0; i<8; i++) {
                    if(oldCell.isBranch(i)) {
                        _recurseLeaf(oldLeaves, newLeaves);
                        newLeaves++;
                    }
                    oldLeaves++;
                }
            }
        }

        void _recurseSubCell2(M5SubCell2* oldCell, M5SubCell2* newCell) {
            newCell.bits = oldCell.bits;

            if(oldCell.isSolid) {
                newCell.offset.set(0xffff_ffff);
            } else if(oldCell.isAir) {
                newCell.offset.set(0);
            } else {

                uint oldOffset = oldCell.offset.get();
                auto p = oldOffset in oldToNewOffset;
                if(p) {
                    if(*p==0) {
                        // This is the original. Set the new offset and continue
                        oldToNewOffset[oldOffset] = dest/4;
                    } else {
                        // This is a duplicate
                        newCell.offset.set(oldToNewOffset[oldOffset]);
                        return;
                    }
                }


                newCell.offset.set(dest/4);
                dest += oldCell.numBranches() * M5SubCell3.sizeof;

                auto oldCell3s = cast(M5SubCell3*)(voxels.ptr    + oldCell.offset.get()*4);
                auto newCell3s = cast(M5SubCell3*)(newVoxels.ptr + newCell.offset.get()*4);

                for(auto i=0; i<64; i++) {
                    if(oldCell.isBranch(i)) {
                        _recurseSubCell3(oldCell3s, newCell3s);
                        newCell3s++;
                    }
                    oldCell3s++;
                }
            }
        }

        void _recurseSubCell1(M5SubCell1* oldCell, M5SubCell1* newCell) {
            /// Cell contents have already been copied.
            /// We just need to adjust the offsets
            if(!oldCell.isAir) {
                newCell.offset.set(dest/4);
                dest += oldCell.numBranches() * M5SubCell2.sizeof;

                auto oldCell2s = cast(M5SubCell2*)(voxels.ptr    + oldCell.offset.get()*4);
                auto newCell2s = cast(M5SubCell2*)(newVoxels.ptr + newCell.offset.get()*4);

                for(auto i=0; i<64; i++) {
                    if(oldCell.isBranch(i)) {
                        _recurseSubCell2(oldCell2s, newCell2s);
                        newCell2s++;
                    }
                    oldCell2s++;
                }
            }
        }

        /// Copy the root
        newVoxels[0..dest] = voxels[0..dest];

        /// Recurse through the cells, updating the offsets
        auto oldCells = cast(M5SubCell1*)(voxels.ptr+8);
        auto newCells = cast(M5SubCell1*)(newVoxels.ptr+8);

        for(auto i=0; i<M5_CELLS_PER_CHUNK; i++) {
            _recurseSubCell1(oldCells++, newCells++);
        }

        return newVoxels[0..dest];
    }
}