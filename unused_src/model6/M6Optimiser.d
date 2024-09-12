module blockie.model.model6.M6Optimiser;

import blockie.model;

/*
    in:
        M6Root view.root
    out:
    (M6AirRoot):
    0:
        ubyte root flag
        ubyte _reserved
        Distance6
    8:
    (chunk cell data:)
        uint[1024] cellFlags;
            // 1 bit per cell: 0=air, 1=mixed
            // (if flag=1 and cellOffset = 0xffffff then cell is SOLID and there is no mixed cell data)

    8+4096:
        // 32768 * 3 bytes (use cellFlags to determine type)
        Offset3[] cellOffsets;       // offset/4 of mixed cell data
        Distance3[] cellDistances;   // one per air cell

    8+4096+98304: (NUM_UNIQ_OFFSETS)
        uint numUniqXYBits;
        uint numUniqZBits;
        uint numUniqCounts;

    // A = UNIQ_BITS_AND_COUNTS_OFFSET = 8+4096+98304 + 3*uint (102420 = 25605*4)
    // B = CELL_DATA_OFFSET = A + numUniqXYBits*4 + numUniqZBits*4 + numUniqCounts * 10bits (round up to uint)

    UNIQ_BITS_AND_COUNTS_OFFSET:
    A:
        uint[] xyBits       // uniq uint bit values
        uint[] zBits;       // uniq uint bit values
        10bit[] xyCounts    // uniq 10-bit count values

    B:
    CELL_DATA_OFFSET: (aligned to uint)

    // align(uint) per cell
    (per mixed cell): (cellOffset points here)
    C0:
        uint xRanks
        uint yRanks
        4-bits bitsPerXYBits (BPXY-1)
        4-bits bitsPerZValues (BPZ-1)
        4-bits bitsPerCount (BPC-1)
        4-bits _reserved
    C1: C0 + 10:                            // xyBits offset
        32 xyBits codings
    C2: C1 + 32*BPXY: (byte aligned)        // xyCounts offset
        32 xyCounts codings
    C3: C2 + 32*BPC (byte aligned)          // zBits offset
        0..1023 zBits codings

*/
final class M6Optimiser {
private:
    M6ChunkEditView view;

    uint[] uniqXYBits;
    uint[] uniqZBits;
    uint[] uniqCounts;

    uint[uint] xyIndexes;
    uint[uint] zIndexes;
    uint[uint] countIndexes;

    // Stats
    static uint totalChunks;
    static uint totalNonAirChunks;
    static uint totalCells;
    static uint totalAirCells;
    static uint totalMixedCells;
    static uint totalSolidCells;
    static ulong totalVoxelsLength;

    const DEBUG_CELL = 11778;
public:
    this(M6ChunkEditView view) {
        this.view = view;
    }
    ubyte[] optimise() {
        totalChunks++;
        totalCells += M6_CELLS_PER_CHUNK;

        if(view.isAir()) {
            return cast(ubyte[])[M6Flag.AIR, 0] ~ view.airRoot.distance.toBytes();
        }

        GC.collect();
        ulong used = GC.stats.usedSize;
        ulong free = GC.stats.freeSize;
        writefln("used = %s, free = %s", used, free);

        totalNonAirChunks++;

        getUniques();

        testEncode1();

        writefln("Total chunks         = %s (air %s)", totalChunks, totalChunks-totalNonAirChunks);
        writefln("Total cells          = %s", totalCells);
        writefln("Total mixed cells    = %s", totalMixedCells);
        writefln("Total air cells      = %s", totalAirCells);
        writefln("Total solid cells    = %s", totalSolidCells);

        return rewriteVoxels();
    }
private:
    void testEncode1() {
        uint numBits;
        foreach(i; 0..M6_CELLS_PER_CHUNK) {
            if(!view.mixedRoot.isAirCell(i)) {
                M6MixedCell* cell = &view.mixedRoot.cells[i].mixed;

                if(cell.isSolid()) {
                    continue;
                }

                uint a = getMaxIndex(cell.xyBits, xyIndexes) + 1;
                numBits += 4 + bitsRequiredToEncode2(a) * 32;

                uint b = getMaxIndex(cell.xyCounts, countIndexes) + 1;
                numBits += 4 + bitsRequiredToEncode2(b) * 32;

                uint c = getMaxIndex(cell.zValues, zIndexes) + 1;
                numBits += cell.zValues.length == 0 ? 0 : 4;
                numBits += bitsRequiredToEncode2(c) * cell.zValues.length;

                // align to uint
                numBits += 31;
                numBits &= ~31;
            }
        }
        // unique bits and counts
        numBits += xyIndexes.length * 32;
        numBits += zIndexes.length * 32;
        numBits += ((countIndexes.length * 10 + 31) & ~31);

        // Header
        numBits += 25605*32;

        static uint total = 0;

        total += numBits;

        writefln("[1] numBytes = %s", total/8);

        //                           xyz         zyx
        // 1  =     786,154 ==>   1,083,136      843,344
        // 2  =     276,770 ==>   2,540,280    2,540,240
        // 3  =   1,369,869 ==>   6,167,022    6,166,128
        // 4  = 189,906,529 ==> 233,039,910  237,438,304
        // 4b =  35,959,516 ==>  46,317,454   46,531,608
        // 4c =  52,915,773 ==>  62,809,920   62,479,828
        // 5  =   1,206,396 ==>   1,341,888    1,354,852
        // 6  =  45,794,558 ==>  48,229,210   55,013,436
        // 7  =  53,213,288 ==>  56,811,410   63,890,388
        // 8  =     758,569 ==>     882,604      947,040

        //writefln("");

        //1,294,456
    }
    uint getMaxIndex(uint[] values, uint[uint] indexes) {
        uint max = 0;
        foreach(v; values) {
            uint index = indexes[v];
            max = maxOf(max, index);
        }
        return max;
    }
    uint[uint] createIndexes(uint[] orderedValues) {
        uint[uint] indexes;
        foreach(i, v; orderedValues) {
            indexes[v] = i.as!uint;
        }
        return indexes;
    }
    void getUniques() {
        uint[uint] countsHash;
        uint[uint] xyHash;
        uint[uint] zHash;

        uint count;

        void _hash(K)(ref uint[K] hash, K[] values) {
            foreach(v; values) {
                auto p = v in hash;
                if(p) {
                    (*p)++;
                } else {
                    hash[v] = 1;
                }
            }
        }
        Tuple!(K,uint)[] _sort(K)(uint[K] hash) {
            return hash.byKeyValue()
                       .map!(it=>tuple(it.key, it.value))
                       .array
                       .sort!((a,b)=>a[1] > b[1])
                       .array;
        }

        foreach(i; 0..M6_CELLS_PER_CHUNK) {
            if(!view.mixedRoot.isAirCell(i)) {
                M6MixedCell* cell = &view.mixedRoot.cells[i].mixed;

                _hash(countsHash, cell.xyCounts);
                _hash(xyHash, cell.xyBits);
                _hash(zHash, cell.zValues);

                count++;
                totalMixedCells++;
            } else {
                totalAirCells++;
            }
        }

        Tuple!(uint,uint)[] counts = _sort(countsHash);
        Tuple!(uint,uint)[] xy     = _sort(xyHash);
        Tuple!(uint,uint)[] z      = _sort(zHash);

        this.uniqXYBits = xy.map!(it=>it[0]).array;
        this.uniqZBits  = z.map!(it=>it[0]).array;
        this.uniqCounts = counts.map!(it=>it[0]).array;

        this.countIndexes   = createIndexes(counts.map!(it=>it[0]).array);
        this.xyIndexes      = createIndexes(xy.map!(it=>it[0]).array);
        this.zIndexes       = createIndexes(z.map!(it=>it[0]).array);

        writefln("Num uniq XY Bits = %s", uniqXYBits.length);
        writefln("Num uniq XY Counts = %s", uniqCounts.length);
        writefln("Num uniq Z Bits = %s", uniqZBits.length);

        uint totalXY = xyHash.values().sum();
        uint totalZ  = zHash.values().sum();
        uint totalC  = countsHash.values().sum();

        writefln("xy.length = %s", totalXY);
        writefln("z.length  = %s", totalZ);
        writefln("C.length  = %s", totalC);

        writefln("uniqXYBits = %s", uniqXYBits);
        writefln("");
        writefln("XYBits ratios = %s", xy.map!(it=>it[1]).array);
        writefln("");
        writefln("XYBits ratios %% = %s", xy.map!(it=>it[1]).map!(it=>(it*100.0)/totalXY).array);
        writefln("");
        writefln("uniqZBits = %s", uniqZBits);
        writefln("");
        writefln("zBits ratios = %s", z.map!(it=>it[1]).array);
        writefln("");
        writefln("zBits ratios %% = %s", z.map!(it=>it[1]).map!(it=>(it*100.0)/totalZ).array);
        writefln("");
        writefln("uniqCounts = %s", uniqCounts);
        writefln("");
        writefln("counts ratios = %s", counts.map!(it=>it[1]).array);
        writefln("");
        writefln("counts ratios %% = %s", counts.map!(it=>it[1]).map!(it=>(it*100.0)/totalC).array);
        writefln("");
    }
    ubyte[] rewriteVoxels() {
        writefln("rewriting voxels");
        ubyte[] voxels = new ubyte[8];
        M6Root* root   = view.mixedRoot;
        uint numSolidCells;

        // Set 8 byte header
        voxels[0..8] = root.as!(ubyte*)[0..8];

        // set cellFlags
        uint[M6_CELLS_PER_CHUNK/32] cellFlags;
        foreach(i; 0..M6_CELLS_PER_CHUNK) {
            if(!root.isAirCell(i)) {
                uint r = i & 31;
                cellFlags[i>>5] |= (1<<r);
            }
        }
        expect(voxels.length == 8);
        voxels ~= cast(ubyte[])cellFlags;
        expect(voxels.length == 8+4096);

        // offsets or distances
        Offset3[M6_CELLS_PER_CHUNK] offsets;
        Distance3* distances = offsets.ptr.as!(Distance3*);

        expect(offsets.sizeof == 3 * M6_CELLS_PER_CHUNK);

        auto mixed = new ArrayBitWriter(65536);

        // set distances, offsets and mixed cell data
        foreach(i; 0..M6_CELLS_PER_CHUNK) {
            if(root.isAirCell(i)) {
                distances[i] = root.cells[i].distance;
            } else {
                // write mixed cell to bytes
                auto cell = &root.cells[i].mixed;

                if(cell.isSolid()) {
                    // Special value indicating solid
                    offsets[i] = Offset3(0xff_ffff);
                    numSolidCells++;
                } else {
                    uint offset = mixed.length();
                    assert(offset%4==0);
                    offsets[i] = Offset3(offset/4);

                    if(i==DEBUG_CELL) {
                        writefln("C0 = %s", mixed.length);
                        writefln("DEBUG_CELL ------> offset %s xRank %032b yRank %032b", offsets[i],
                            cell.getXRankBits(), cell.getYRankBits()
                            );
                        foreach(n, j; cell.xyBits) {
                            writefln("[%s]  %032b", n, j);
                        }
                        writefln("zValues -->");
                        foreach(n, k;cell.zValues) {
                            writefln("[%s]  %032b", n, k);
                        }

                        writefln("xyCounts -->");
                        foreach(n, k;cell.xyCounts) {
                            writefln("[%s]  %s", n, k);
                        }

                        //writefln("xyBits[16] = %s", cell.xyBits[16]);
                    }

                    // xRanks
                    mixed.write(cell.getXRankBits(), 32);
                    // yRanks
                    mixed.write(cell.getYRankBits(), 32);

                    // 4-bits bitsPerXYBits (BPXY)
                    // 4-bits bitsPerZValues (BPZ)
                    // 4-bits bitsPerCount (BPC)
                    // 4-bits _reserved
                    uint bpxy = bitsRequiredToEncode2(getMaxIndex(cell.xyBits, xyIndexes) + 1);
                    uint bpz = bitsRequiredToEncode2(getMaxIndex(cell.zValues, zIndexes) + 1);
                    uint bpc = bitsRequiredToEncode2(getMaxIndex(cell.xyCounts, countIndexes) + 1);
                    expect(bpxy>0);
                    expect(bpz>0);
                    expect(bpc>0);
                    expect(bpxy < 17);
                    expect(bpz < 17);
                    expect(bpc < 17);
                    mixed.write(bpxy-1, 4);   // 4-bits bitsPerXYBits (BPXY)
                    mixed.write(bpz-1, 4);    // 4-bits bitsPerZValues (BPZ)
                    mixed.write(bpc-1, 4);    // 4-bits bitsPerCount (BPC)
                    mixed.write(0, 4);        // 4-bits _reserved

                    if(i==DEBUG_CELL) {
                        writefln("bpxy = %s", bpxy);
                        writefln("bpz  = %s", bpz);
                        writefln("bpc  = %s", bpc);
                    }

                    // xyBits codings
                    foreach(n, j; cell.xyBits) {
                        if(i==DEBUG_CELL) {
                            writefln("[%s] xyBits index = %s (%08x)", n, xyIndexes[j], j);
                        }
                        mixed.write(xyIndexes[j], bpxy);
                    }
                    assert(mixed.bitsWritten%8==0);

                    // xyCounts codings (byte aligned)
                    foreach(n, j; cell.xyCounts) {
                        if(i==DEBUG_CELL) {
                             writefln("[%s] xyCounts index = %s (%s)", n, countIndexes[j], j);
                        }
                        mixed.write(countIndexes[j], bpc);
                    }
                    assert(mixed.bitsWritten%8==0);

                    // zValues codings (byte aligned)
                    foreach(n, j; cell.zValues) {
                        if(i==DEBUG_CELL) {
                            writefln("[%s] zValues index = %s (%08x)", n, zIndexes[j], j);
                        }
                        mixed.write(zIndexes[j], bpz);
                    }

                    // move to next multiple of uint
                    mixed.alignTo(32);
                    assert(mixed.bitsWritten%32==0);
                }
            }
        }

        voxels ~= cast(ubyte[])offsets;

        writefln("OFFSET %s = %s", DEBUG_CELL, offsets[DEBUG_CELL]);

        uint numUniqXYBits = uniqXYBits.length.as!uint;
        uint numUniqZBits  = uniqZBits.length.as!uint;
        uint numUniqCounts = uniqCounts.length.as!uint;

        chat("numUniqXYBits .. %s", numUniqXYBits);
        chat("numUniqZBits ... %s", numUniqZBits);
        chat("numUniqCounts .. %s", numUniqCounts);

        uint[] nums = [numUniqXYBits, numUniqZBits, numUniqCounts];

        voxels ~= cast(ubyte[])nums;

        // A = 8+4096+98304 + 3*uint (102420)
        uint A = 8+4096+ 32768*3 + uint.sizeof*3;
        expect(A%4==0);
        expect(voxels.length == 102420);
        chat("A = %s", A);

        // uniq xyBits
        auto xyBits = new ArrayByteWriter(8192);
        foreach(i; uniqXYBits) {
            xyBits.write!uint(i);
        }

        // uniq zBits
        auto zBits = new ArrayByteWriter(8192);
        foreach(i; uniqZBits) {
            zBits.write!uint(i);
        }

        // uniq counts
        auto counts = new ArrayBitWriter(8192);
        foreach(i; uniqCounts) {
            counts.write(i, 10);
        }
        counts.alignTo(32);

        voxels ~= xyBits.getArray();
        voxels ~= zBits.getArray();
        voxels ~= counts.getArray();

        writefln("counts %s %s %s", uniqCounts.length, counts.length, counts.bitsWritten);
        writefln("==> %s %s", (numUniqCounts*10+31)/32*4, (numUniqCounts*10+31)/32*4);

        uint B = A + numUniqXYBits*4 + numUniqZBits*4 + (numUniqCounts*10+31)/32*4;
        expect(voxels.length == 102420 + numUniqXYBits*4 + numUniqZBits*4 + ((numUniqCounts*10+31)/32*4));
        chat("B = %s", B);

        // B: Must be a multiple of uint here
        expect(B%4==0);

        // Write mixed cell bits here:
        voxels ~= mixed.getArray();

        writefln("mixed.length() = %s", mixed.length());

        totalSolidCells += numSolidCells;

        writefln("Rewritten %s bytes", voxels.length);

        totalVoxelsLength += voxels.length;

        writefln("TOTAL = %s", totalVoxelsLength);

        return voxels;
    }
}
