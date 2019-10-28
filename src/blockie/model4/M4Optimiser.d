module blockie.model4.M4Optimiser;

import blockie.all;

final class M4Optimiser : Optimiser {
private:
    M4ChunkEditView view;
public:
    this(M4ChunkEditView view) {
        this.view = view;
    }
    override ubyte[] optimise(ubyte[] voxels, uint voxelsLength) {

        /// This chunk is AIR. Nothing to do
        if(view.isAir) {
            return cast(ubyte[])[M4Root.Flag.AIR, 0] ~ view.root().distance.toBytes();
        }

        writefln("Optimiser: Processing %s", view);

        auto optVoxels = rewriteVoxels(voxels);

        writefln("\tOptimised chunk %s %000,d --> %000,d (%.2f%%)", view.getChunk.pos,
            voxels.length, optVoxels.length, optVoxels.length*100.0 / voxels.length);

        return optVoxels;
    }
private:
    /**
     *  Re-write octrees to be in order and remove any gaps.
     */
    ubyte[] rewriteVoxels(ubyte[] srcVoxels) {

        auto destVoxels = new ubyte[srcVoxels.length];
        uint dest       = 0;

        expect(view.cellOffsets.length == view.root().l7popcounts[$-1]);

        auto numBranches = 0;
        auto numCells = 0;

        ubyte[] L100Bits;
        uint[] L100Popcounts;

        ubyte[] branchEncBytes;
        uint[ulong] uniqBranchesMap;
        ulong[] uniqBranches;
        ulong[] allBranches;
        uint bitsPerBranch;

        M4Root* srcRoot() { return cast(M4Root*)srcVoxels.ptr; }

        M4Cell* getSrcCell(uint cell) {
            return cast(M4Cell*)(srcVoxels.ptr + view.cellOffsets[cell]);
        }

        void recurse() {

            void recurseBranch(M4Branch* srcBranch, uint cell, uint branch) {

                expect(srcBranch.bits!=0);

                numBranches++;

                auto srcLeaves  = cast(M4Leaf*)(srcVoxels.ptr  + srcBranch.offset.get());

                auto allLeaves = 0L;

                for(auto i=0; i<8; i++) {
                    allLeaves <<= 8;
                    if(srcBranch.isLeaf(i)) {
                        allLeaves |= srcLeaves.bits;
                    }
                    srcLeaves++;
                }

                import core.bitop : bswap;

                allLeaves = bswap(allLeaves);

                if(allLeaves !in uniqBranchesMap) {
                    uniqBranchesMap[allLeaves] = uniqBranchesMap.length.as!uint;
                    uniqBranches ~= allLeaves;
                }

                allBranches ~= allLeaves;
            }

            void recurseCell(M4Cell* srcCell, uint cell) {
                expect(srcCell.bits!=0);

                numCells++;

                L100Bits ~= srcCell.bits;

                auto srcBranches = cast(M4Branch*)(srcVoxels.ptr + srcCell.offset.get());

                for(auto i=0; i<8; i++) {
                    if(srcCell.isBranch(i)) {
                        recurseBranch(srcBranches, cell, i);
                    }
                    srcBranches++;
                }
            }

            for(auto cell=0; cell<M4_CELLS_PER_CHUNK; cell++) {
                if(!srcRoot().isAirCell(cell)) {
                    recurseCell(getSrcCell(cell), cell);
                }
            }
        }
        void adjustBitsLengths() {
            /// Align bits to 4 bytes
            if(L100Bits.length%4!=0) {
                L100Bits.length += (4-L100Bits.length%4);
            }
            expect(L100Bits.length%4==0);
            writefln("L100Bits.length = %s", L100Bits.length);
        }
        void calculateBranchPtrs() {

            bitsPerBranch = bitsRequiredToEncode2(uniqBranches.length);
            writefln("bitsPerBranch = %s", bitsPerBranch);

            void writeByte(ubyte b) {
                branchEncBytes ~= b;
            }
            auto writer = new BitWriter(&writeByte);

            foreach(i, branch; allBranches) {
                uint index = uniqBranchesMap[branch];
                writer.write(index, bitsPerBranch);
            }
            writer.flush();

            /// Make length a multiple of 4 bytes
            if(branchEncBytes.length%4!=0) {
                branchEncBytes.length += (4-branchEncBytes.length%4);
            }
        }
        void calculatePopcounts() {
            uint sum = 0;
            L100Popcounts.length = L100Bits.length / 4;

            for(auto i=0; i<L100Bits.length/4; i++) {
                sum += popcnt(L100Bits[i*4+0]);
                sum += popcnt(L100Bits[i*4+1]);
                sum += popcnt(L100Bits[i*4+2]);
                sum += popcnt(L100Bits[i*4+3]);
                L100Popcounts[i] = sum;
            }
        }
        void write() {

            dest = 0;
            uint numCells = view.root().l7popcounts[$-1];

            void writeUbyte(ubyte value) {
                (destVoxels.ptr+dest)[0] = value;
                dest++;
            }
            void writeUint(uint value) {
                auto ptr = cast(uint*)(destVoxels.ptr+dest);
                ptr[0] = value;
                dest += 4;
            }
            void copy(uint src, uint numBytes) {
                destVoxels[dest..dest+numBytes] = srcVoxels[src..src+numBytes];
                dest += numBytes;
            }
            void copyArray(T)(T[] values) {
                auto ptr = cast(T*)(destVoxels.ptr+dest);
                ptr[0..values.length] = values;
                dest += values.length*T.sizeof;
            }

            /// [0]      M4Root
            ///
            /// [561748] L100BitsLength     (4 bytes)
            /// [561752] NumUniqBranches    (4 bytes)

            /// [561756] L100 bits          (L100BitsLength bytes)
            ///          L100 popcounts     (L100BitsLength bytes)

            ///          UniqBranches       (NumUniqBranches * 8 bytes)
            ///          Cell distances     (4 * (1<<M4_CELL_LEVEL) bytes)
            ///          Branch Ptrs        (NumBrances * enc bits)

            copy(0, M4_ROOT_SIZE); /// M4Root (561748 bytes)

            expect(dest%4==0);
            expect(M4Root.l7bits.offsetof%4==0);
            expect(M4Root.l7popcounts.offsetof%4==0);

            expect(dest==561748);
            writeUint(L100Bits.length.as!uint);      /// L100BitsLength
            writeUint(uniqBranches.length.as!uint);  /// NumUniqBranches


            expect(dest==561756);
            copyArray!ubyte(L100Bits);   /// L100 bits

            expect(dest==561756+L100Bits.length);
            copyArray!uint(L100Popcounts);       /// L100 popcounts


            expect(dest==561756+L100Bits.length*2);
            copyArray!ulong(uniqBranches);     /// UniqBranches

            expect(dest==561756+L100Bits.length*2+uniqBranches.length*8);
            copyArray!uint(view.cellDistances);  /// cell distances

            expect(dest==561756+L100Bits.length*2+uniqBranches.length*8 +
                         view.cellDistances.length*uint.sizeof);
            copyArray!ubyte(branchEncBytes);   /// Branch ptrs
        }

        recurse();
        adjustBitsLengths();
        calculateBranchPtrs();
        calculatePopcounts();
        write();

        writefln("num cells    = %000,d", numCells);
        writefln("num branches = %000,d", numBranches);
        writefln("uniqBranches = %000,d (%s bits)", uniqBranchesMap.length, bitsRequiredToEncode(uniqBranchesMap.length));

        static ulong TOTAL = 0;
        TOTAL += dest;
        writefln("TOTAL = %000,d", TOTAL);

        writefln("dest = %000,d", dest);

        return destVoxels[0..dest];
    }
}
