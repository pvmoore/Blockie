module blockie.model3.M3bOptimiser;

import blockie.model;

import common : add, getOrAdd;

/**
 *  Convert edit-optimised voxels into render-optimised voxels.
 *
 *  [00000] M3Root {
 *      M3Flag      flag
 *      ubyte       reserved
 *      Distance6   distance;    // if flag==AIR
 *  }
 *
 */
final class M3bOptimiser : Optimiser {
private:
    M3ChunkEditView view;
public:
    /**
     * Header
     *      [00000] M3Flag, 3 reserved bytes (4 bytes)
     *      [00004] Cell solid flags         (4096 bytes) 1 = solid cell, 0 = air or mixed
     *      [04100] Cell bit flags           (4096 bytes) 0 = air, 1 = mixed
     *      [08196] Cell flag pop counts     (4092 bytes)
     *      [12288] PopcountsA offset/4      (4 bytes)
     *      [12292] PopcountsB offset/4      (4 bytes)
     *      [12296] PopcountsC offset/4      (4 bytes)
     *      [12300] BitsA offset/4           (4 bytes)
     *      [12304] BitsB offset/4           (4 bytes)
     *      [12308] BitsC offset/4           (4 bytes)
     *      [12312] offsetIndexes/4          (4 bytes)
     *      [12316] offsetLeaves/4           (4 bytes)
     *      [12320] numIndexBits             (4 bytes)
     * [12324] End of Header
     */
    static struct Header { align(1):
        M3Flag flag; ubyte[3] _reserved;    // [00000] M3Flag, 3 reserved bytes
        ubyte[4096] cellSolidFlags;         // [00004] Cell solid flags (4096 bytes)
        ubyte[4096] cellBitFlags;           // [04100] Cell bit flags (4096 bytes)
        uint[1023] cellPopcounts;           // [08196] Cell flag pop counts (4092 bytes)
        uint offsetPopcountsA;              // [12288] PopcountsA offset
        uint offsetPopcountsB;              // [12292] PopcountsB offset
        uint offsetPopcountsC;              // [12296] PopcountsC offset
        uint offsetBitsA;                   // [12300] BitsA offset
        uint offsetBitsB;                   // [12304] BitsB offset
        uint offsetBitsC;                   // [12308] BitsC offset
        uint offsetIndexes;                 // [12312] Indexes offset
        uint offsetLeaves;                  // [12316] LeavesOffset
        uint numIndexBits;                  // [12320] num bits per index
                                            // [12324]
        static assert(Header.sizeof == 12324);

        string toString() {
            string s = "Header {" ~
                "\n\tflag: %s".format(flag) ~
                "\n\tcellSolidFlags: %s...".format(cellSolidFlags[0..7]) ~
                "\n\tcellBitFlags: %s...".format(cellBitFlags[0..7]) ~
                "\n\tcellPopcounts: %s...".format(cellPopcounts[0..7]) ~
                "\n\toffsetPopcountsA: %s".format(offsetPopcountsA) ~
                "\n\toffsetPopcountsB: %s".format(offsetPopcountsB) ~
                "\n\toffsetPopcountsC: %s".format(offsetPopcountsC) ~
                "\n\toffsetBitsA: %s".format(offsetBitsA) ~
                "\n\toffsetBitsB: %s".format(offsetBitsB) ~
                "\n\toffsetBitsC: %s".format(offsetBitsC) ~
                "\n\toffsetIndexes: %s".format(offsetIndexes) ~
                "\n\toffsetLeaves: %s".format(offsetLeaves) ~
                "\n\tNumIndexBits: %s".format(numIndexBits)
                ;
            return s ~ "\n}";
        }
    }
    // ─────────────────────────────────────────────────────────────────────────────────────────────
    this(M3ChunkEditView view) {
        this.view = view;
    }

    override ubyte[] optimise(ubyte[] voxels, uint voxelsLength) {

        if(view.isAir) {
            return cast(ubyte[])[M3Flag.AIR, 0] ~ view.root().distance.toBytes();
        }

        writefln("Optimising %s\n\tStart voxels length        = %s", view.getChunk.pos, voxelsLength);

        auto optVoxels = rewriteVoxels(voxels[0..voxelsLength]);

        writefln("\toptimised %s --> %s (%.2f%%)",
            voxelsLength, optVoxels.length, optVoxels.length*100.0 / voxelsLength);

        return optVoxels;
    }
private:
    // ═════════════════════════════════════════════════════════════════════════════════════════════
    /**
     *    0         1        2     uint index
     *   [2]       [5]       -     popcounts
     * 01010000 00011100 01101100  bits
     */
    uint[] calcUintPopCounts(ubyte[] bits) {
        uint total = 0;
        uint[] popcounts;
        foreach(i, b; bits) {
            if(i > 0 && (i&3)==0) {
                popcounts ~= total;
            }
            total += popcnt(b);
        }
        return popcounts;
    }

    /**
     * ┌─────────────────────────────────────
     * │ Header: [10,9,8,7,6]
     * │ cellSolidFlags
     * │ cellBitFlags
     * │ cellPopcounts
     * │ cellDistances
     * │ OffsetBitsA
     * │ OffsetBitsB
     * │ OffsetBitsC
     * │ OffsetPopcountsA
     * │ OffsetPopcountsB
     * │ OffsetPopcountsC
     * │ OffsetIndexes
     * │ OffsetLeafBundles
     * │ IndexNumEntropyBits
     * └─────────────────────────────────────┘
     * ┌─────────────────────────────────────┐
     * │ Cell
     * │ bitsA (popCountsA) [oct4]
     * └─────────────────────────────────────
     *  🡦
     *   ┌─────────────────────────────────────┐
     *   │ Branch
     *   │ bitsB (popcountsB) [oct3]           │
     *   └─────────────────────────────────────┘
     *    🡦
     *     ┌─────────────────────────────────────┐
     *     │ Branch
     *     │ bitsC (popcountsC) [oct2]           │
     *     └─────────────────────────────────────┘
     *      🡦
     *       ┌─────────────────────────────────────────────────────
     *       │ indexes (pointing to unique leaves [oct1 and oct0])
     *       └─────────────────────────────────────────────────────
     *       ┌─────────────────────────────────────
     *       │ Unique Leaf Bundles (8 bytes each)
     *       └─────────────────────────────────────
     */
    ubyte[] rewriteVoxels(ubyte[] voxels) {

        auto cellSolidFlags = new ArrayBitWriter();
        auto cellBitFlags = new ArrayBitWriter();
        ubyte[] cellDistances;

        ubyte[] bitsA;
        ubyte[] bitsB;
        ubyte[] bitsC;

        M3Branch solidBranch = M3Branch(0xff, Offset3(0xff_ffff));

        uint dbgNumAirCells;
        uint[ulong] uniqLeafBundles; // K = Leaf Bundle, V = index
        uint[] indexes;

        uint cellNum, oct4, oct3, oct2;

        /** 64 voxels per branch */
        void _recurseC(M3Branch* branchC) {

            ulong leaf;

            // iterate bitsD - Each bit represents 8 voxels
            foreach(uint oct1; 0..8) {

                leaf <<= 8;

                if(branchC.isSolid()) {
                    leaf |= 0xff;
                } else if(!branchC.isAir(oct1)) {
                    auto leafPtr = branchC.getLeaf(voxels.ptr, oct1);
                    leaf |= leafPtr.bits;
                }
            }

            import core.bitop : bswap;
            leaf = bswap(leaf);

            // Assign an index to this leaf if it has not already been seen
            if(!uniqLeafBundles.containsKey(leaf)) {
                uniqLeafBundles[leaf] = uniqLeafBundles.length.as!uint;
            }

            // FIXME(performance) - write the leafBundles at this point. No need to sort them later

            indexes ~= uniqLeafBundles[leaf];
        }

        /** 512 voxels per branch */
        void _recurseB(M3Branch* branchB) {

            bitsC ~= branchB.bits;

            // iterate bitsC - Each bit represents 64 voxels
            if(branchB.isSolid()) {
                for(oct2=0; oct2<8; oct2++) {
                    _recurseC(&solidBranch);
                }
            } else {
                for(oct2=0; oct2<8; oct2++) {
                    if(!branchB.isAir(oct2)) {
                        _recurseC(branchB.getBranch(voxels.ptr, oct2));
                        //_recurseC(branchB.getBranch(voxels.ptr, oct2));
                    }
                }
            }
        }

        /** 4096 voxels per branch */
        void _recurseA(M3Branch* branchA) {

            bitsB ~= branchA.bits;

            // Iterate bitsB - Each bit represents 512 voxels
            if(branchA.isSolid()) {
                for(oct3=0; oct3<8; oct3++) {
                    _recurseB(&solidBranch);
                }
            } else {
                for(oct3=0; oct3<8; oct3++) {
                    if(!branchA.isAir(oct3)) {
                        _recurseB(branchA.getBranch(voxels.ptr, oct3));
                    }
                }
            }
        }

        void _recurseCell(M3Cell* cell) {

            if(cell.isSolid()) {
                // This cell is SOLID
                cellSolidFlags.writeOnes(1);
                cellBitFlags.writeZeroes(1);

                // Dummy values because bit flag is zero
                cellDistances ~= 0;
                cellDistances ~= 0;
                cellDistances ~= 0;

            } else if(cell.isAir()) {
                // This cell is AIR
                dbgNumAirCells++;
                cellSolidFlags.writeZeroes(1);
                cellBitFlags.writeZeroes(1);

                cellDistances ~= cell.distance.x;
                cellDistances ~= cell.distance.y;
                cellDistances ~= cell.distance.z;

            } else {
                // This cell is MIXED
                cellSolidFlags.writeZeroes(1);
                cellBitFlags.writeOnes(1);

                bitsA ~= cell.bits;

                // Iterate bitsA - Each bit represents 4096 voxels
                for(oct4=0; oct4<8; oct4++) {
                    if(cell.isBranch(oct4)) {
                        _recurseA(cell.getBranch(voxels.ptr, oct4));
                    }
                }
            }
        }

        auto srcCells = cast(M3Cell*)(voxels.ptr+8);

        writefln("Recursing cells");
        for(cellNum=0; cellNum<M3_CELLS_PER_CHUNK; cellNum++) {
            _recurseCell(srcCells++);
        }
        writefln("Finished recursing cells");

        // ─────────────────────────────────────────────────────────────────────────────────────────

        assert(cellSolidFlags.bitsWritten == 32768, "cellSolidFlags.bitsWritten = %s".format(cellSolidFlags.bitsWritten));
        assert(cellBitFlags.bitsWritten == 32768, "cellBitFlags.bitsWritten = %s".format(cellBitFlags.bitsWritten));
        assert(cellDistances.length == dbgNumAirCells*3);

        uint[] cellPopcounts = calcUintPopCounts(cellBitFlags.getArray());
        uint[] popcountsA = calcUintPopCounts(bitsA);
        uint[] popcountsB = calcUintPopCounts(bitsB);
        uint[] popcountsC = calcUintPopCounts(bitsC);

        assert(cellPopcounts.length == 1023);

        auto dbgHeaderTotal =
            8 +
            cellSolidFlags.bytesWritten +
            cellBitFlags.bytesWritten +
            cellPopcounts.length*4 +
            4*4 +
            dbgNumAirCells*3;

        auto totalA = bitsA.length + popcountsA.length*4;
        auto totalB = bitsB.length + popcountsB.length*4;
        auto totalC = bitsC.length + popcountsC.length*4;

        auto entropyBits = bitsRequiredToEncode2(uniqLeafBundles.length);

        auto dbgNumIndexBytes = (indexes.length*entropyBits)/8;
        auto dbgLeafBundleBytes = uniqLeafBundles.length*8;

        debug {
            writefln("Header size       : %s", dbgHeaderTotal);
            writefln("Size A            : %s", totalA);
            writefln("Size B            : %s", totalB);
            writefln("Size C            : %s", totalC);
            writefln("Indexes           : %s (%s bytes)", indexes.length, dbgNumIndexBytes);
            writefln("Uniq Leaf bundles : %s (%s bytes)", uniqLeafBundles.length, dbgLeafBundleBytes);
            writefln("Entropy bits      : %s", entropyBits);

            writefln("======================================");
            writefln("Total size = %s",
                dbgHeaderTotal +
                totalA +
                totalB +
                totalC +
                dbgNumIndexBytes +
                dbgLeafBundleBytes);
            writefln("======================================");
        }

        ubyte[] newVoxels = new ubyte[Header.sizeof];

        Header* header() { return cast(Header*)newVoxels.ptr; }

        /** Write the Header */
        {
            auto h = header();
            h.flag = M3Flag.MIXED;
            h.cellSolidFlags = cellSolidFlags.getArray().ptr[0..4096];
            h.cellBitFlags = cellBitFlags.getArray().ptr[0..4096];
            h.cellPopcounts = cellPopcounts[0..1023];
            h.numIndexBits = entropyBits;
        }

        assert(newVoxels.length == 12324);

        /*
         * [12324]
         *  Cell distances (variable length * 3 bytes)
         *  -align(4)-
         *  Popcounts A
         *  Popcounts B
         *  Popcounts C
         *
         *  Bits A
         *  -align(4)-
         *  Bits B
         *  -align(4)-
         *  Bits C
         *  -align(4)-
         *  Indexes
         *  -align(4)-
         *  Leaf bundles
         */

        // [12324] // Cell distances
        newVoxels ~= cellDistances;

        alignToUint(newVoxels); assert(newVoxels.length%4==0);

        // Popcounts A
        header().offsetPopcountsA = newVoxels.length.as!uint / 4;
        newVoxels.add(popcountsA);

        // Popcounts B
        header().offsetPopcountsB = newVoxels.length.as!uint / 4;
        newVoxels.add(popcountsB);

        // Popcounts C
        header().offsetPopcountsC = newVoxels.length.as!uint / 4;
        newVoxels.add(popcountsC);

        // Bits A
        alignToUint(newVoxels); assert(newVoxels.length%4==0);
        header().offsetBitsA = newVoxels.length.as!uint / 4;
        newVoxels.add(bitsA);

        // Bits B
        alignToUint(newVoxels); assert(newVoxels.length%4==0);
        header().offsetBitsB = newVoxels.length.as!uint / 4;
        newVoxels.add(bitsB);

        // Bits C
        alignToUint(newVoxels); assert(newVoxels.length%4==0);
        header().offsetBitsC = newVoxels.length.as!uint / 4;
        newVoxels.add(bitsC);

        // Indexes
        alignToUint(newVoxels); assert(newVoxels.length%4==0);
        header().offsetIndexes = newVoxels.length.as!uint / 4;
        {
            auto indexesBuf = new ArrayBitWriter();
            foreach(idx; indexes) {
                indexesBuf.write(idx, entropyBits);
            }
            indexesBuf.flush();
            newVoxels ~= indexesBuf.getArray();
        }

        // Leaves
        alignToUint(newVoxels); assert(newVoxels.length%4==0);
        header().offsetLeaves = newVoxels.length.as!uint / 4;
        {
            foreach(i, u; uniqLeafBundles.entriesSortedByValue()) {
                ulong key = u[0];
                newVoxels.add([key]);
            }
        }

        writefln("%s", header().toString());

        // 625,616
        writefln("newVoxels.length = %s", newVoxels.length);

        return newVoxels;
    }

/+
    void test(ubyte[] newVoxels) {
        // [12324] // Cell distances

        writefln("testing");

        ubyte[] cellDistances = newVoxels[12324..$];
        uint index = 28653;


        ubyte[] bits = [
            0b0000_1001,
            0b0001_1110,
            0b0100_0100,
            0b1110_0000,    // 11 bits, 32-11 = (21)

            0b0000_1001,    //
            0b0001_1110,
            0b0100_0100,
            0b1110_0000
        ];
        uint[] popcounts = calcUintPopCounts(bits);

        // 32 = 11 (21)
        // 33 = 12 (21)
        // 34 = 12 (22)
        // 35 = 12 (23)
        // 36 = 13 (23)

        uint oct = 36;

        writefln("== %s (%s)",
            countSetBits(bits, popcounts.ptr, oct),
            oct - countSetBits(bits, popcounts.ptr, oct));


    }
    uint countSetBits(ubyte[] bitsArray, uint* popcounts, uint index) {
        uint a   = index / 32;
        uint b   = index & 31;
        uint and = 0x7fff_ffffu >>> (31-b);

        uint bits = bitsArray.ptr.as!(uint*)[a];
        uint count = a == 0 ? 0 : popcounts[a-1];
        return count + popcnt(bits & and);
    }
    +/
}