module blockie.model3.M3ChunkEditView;

import blockie.model;
///
/// Level   | Bits         |                 | Count         | Volume                 |
/// --------+--------------+-----------------+---------------+------------------------|
/// chunk   | 11_1111_1111 | 1 M3Root        |             1 | 1024^3 = 1,073,741,824 |
///  root 5 | 11_1110_0000 | 32768 M3Cells   |        32,768 |   32^3 =        32,768 |
///       4 |       1_0000 | 0..8 M3Branches |       262,144 |   16^3 =         4,096 |
///       3 |         1000 | 0..8 M3Branches |     2,097,152 |    8^3 =           512 |
///       2 |          100 | 0..8 M3Branches |    16,777,216 |    4^3 =            64 |
///       1 |           10 | 0..8 M3Leaves   |   134,217,728 |    2^3 =             8 |
///       0 |            1 | 8 bits          | 1,073,741,824 |      1 =             1 |
final class M3ChunkEditView : ChunkEditView {
private:
    const uint BUFFER_INCREMENT = 1024*512;
    BasicAllocator allocator;
    Optimiser optimiser;

    ubyte[] voxels;
    uint version_;

    uint[6] branchOffsets;
    uint cellOffset;

    uint numEdits;
    uint tempNumEdits;
    StopWatch watch;
public:
    this() {
        this.allocator = new BasicAllocator(0);
        this.optimiser = new M3Optimiser(this);
    }
    ubyte[] getVoxels()           { return voxels; }
    BasicAllocator getAllocator() { return allocator; }
    M3Root* root()                { return cast(M3Root*)voxels.ptr; }

    double megaEditsPerSecond() {
        auto p = (numEdits-tempNumEdits) / (watch.peek().total!"nsecs"*1e-03);
        watch.reset();
        tempNumEdits = numEdits;
        return p;
    }
    ulong getNumEdits() const { return numEdits; }

    override void beginTransaction(Chunk chunk) {
        super.beginTransaction(chunk);

        convertToEditable();
    }
    override void voxelEditsCompleted() {
        root().recalculateFlags();
    }
    override void commitTransaction() {

        auto optVoxels = optimiser.optimise(voxels, voxels.length.as!uint);

        allocator.reset();

        /// Write voxels back to chunk
        uint ver = chunk.atomicUpdate(version_, optVoxels);
        if(ver!=version_+1) {
            /// Stale
            log("M3ChunkEditView: %s is stale", chunk);
        } else {
            log("Chunk %s updated to version %s", chunk, ver);
        }
    }
    override void setVoxel(uint3 offset, ubyte value) {
        watch.start();
        assert(chunk !is null);

        if(value==0) {
            unsetVoxel(offset);
        } else{
            setVoxel(offset);
        }
        watch.stop();
        numEdits++;
    }
    override bool isAir() {
        return root().flag==M3Flag.AIR;
    }
    override bool isAirCell(uint cellIndex) {
        assert(cellIndex<M3_CELLS_PER_CHUNK, "%s".format(cellIndex));
        return root().cells[cellIndex].isAir();
    }
    override void setChunkDistance(DFieldsBi f) {
        root().distance.set(f);
    }
    override void setCellDistance(uint cell, uint x, uint y, uint z) {
        assert(cell<M3_CELLS_PER_CHUNK);

        auto c = root().getCell(voxels.ptr, cell);
        assert(!isAir);
        assert(voxels.length>4, "voxels.length=%s".format(voxels.length));
        assert(c.isAir, "oct=%s bits=%s".format(cell, c.bits));
        c.distance.set(x,y,z);
    }
    override void setCellDistance(uint cell, DFieldsBi f) {

        // Max = 15
        int convert(int v) { return min(v, 15); }

        setCellDistance(cell,
            (convert(f.x.up)<<4) | convert(f.x.down),
            (convert(f.y.up)<<4) | convert(f.y.down),
            (convert(f.z.up)<<4) | convert(f.z.down)
        );
    }



    /*
    void dumpbr(M3Branch* b, int level) {
        writefln("%s", b.toString);
        if(b.isSolid || b.isAir) return;

        string pad = "  ".repeat(7-level);
        for(int i=0; i<8; i++) {
            if(b.isBranch(i)) {
                //writef(pad~"  L%s[oct %s] ", level-1, i);
                if(level-1==1) {
                    writefln(pad~"  L1[lf %s] %08b", i, b.getLeaf(voxels.ptr, i).bits);
                } else {
                    writef(pad~"  L%s[br %s] ", level-1, i);
                    dumpbr(b.getBranch(voxels.ptr, i), level-1);
                }
            }
        }
    }
    void dumpcell(M3Cell* cell, uint oct) {
        writefln("  [Cell %s] %s", oct, cell.toString);
        if(cell.isSolid || cell.isAir) return;

        for(int i=0; i<8; i++) {
            if(cell.isBranch(i)) {
                writef("    L5[br %s] ", i);
                dumpbr(cell.getBranch(voxels.ptr, i), 5);
            }
        }
    }
    void dumprt(M3Root* rt) {
        writefln("%s {", rt.toString);
        if(rt.isMixed) {
            foreach(int oct, cell; rt.cells) {
                dumpcell(&cell, oct);
                //if(oct > 4) break;
            }
        }
        writefln("}");
    }
    void dump() {
        dumprt(getRoot());
        writefln("%s", allocator.toString);
    }
    */

    /**
     * Return true if the voxel at _offset_ is set
     */
    bool getVoxel(uint3 offset) {
        // Root
        if(getRoot().isAir) {
            return false;
        }

        /// MIXED

        /// Level 5 - cell
        uint oct     = getCellOct(offset);
        //writefln("octc = %s", oct);
        M3Cell* cell = getRoot().getCell(voxels.ptr, oct);
        if(cell.isAir()) return false;
        if(cell.isSolid()) return true;

        // Level 4 - BitsA
        oct = getOct(offset, 0b00_0001_0000, 4);
        //writefln("oct4 = %s, bitsA = %x", oct, cell.bits);
        if(cell.isAir(oct)) return false;

        auto branchA = cell.getBranch(voxels.ptr, oct);
        if(branchA.isSolid()) return true;

        //

        // Level 3 - BitsB
        oct = getOct(offset, 0b00_0000_1000, 3);
        //writefln("oct3 = %s bitsB = %x", oct, branchA.bits);
        if(branchA.isAir(oct)) return false;

        auto branchB = branchA.getBranch(voxels.ptr, oct);
        if(branchB.isSolid()) return true;

        //

        // Level 2 - BitsC
        oct = getOct(offset, 0b00_0000_0100, 2);
        //writefln("oct2 = %s, bitsC = %x", oct, branchB.bits);
        if(branchB.isAir(oct)) return false;

        auto branchC = branchB.getBranch(voxels.ptr, oct);
        if(branchC.isSolid()) return true;

        //

        /// Level 1
        oct = getOct(offset, 0b00_0000_0010, 1);
        //writefln("oct1 = %s, bitsD = %x", oct, branchC.bits);
        if(branchC.isAir(oct)) return false;

        M3Leaf* leaf = branchC.getLeaf(voxels.ptr, oct);

        // Level 0 - Voxel
        oct = getOct(offset, 0b00_0000_0001, 0);
        //writefln("oct0 = %s, leaf bits = %x", oct, leaf.bits);

        return leaf.isSet(oct);
    }
    override string toString() {
        return "View %s".format(chunk.pos);
    }
private:
    void convertToEditable() {
        /// Initially only allocate the exact number of voxels used
        /// in case we don't actually make any edits which is likely

        immutable(ubyte)[] originalVoxels;
        chunk.atomicGet(this.version_, originalVoxels);

        this.voxels = originalVoxels.dup;
        this.allocator.resize(voxels.length.as!uint);

        expect(version_!=0, "%s version_ is %s".format(chunk, version_));

        alloc(voxels.length.as!uint);

        expect(allocator.numBytesUsed==voxels.length);
        expect(allocator.numBytesFree==0);
    }
    //void checkBranches() {
    //    expect(getRoot().flag==M3Flag.MIXED);
    //
    //    void*[7] parents;
    //
    //    void followBranch(void* parent, M3Branch* br, int level) {
    //        if(!br.isSolid && !br.isAir) {
    //            if(br.offset.get > 250000) {
    //                writefln("!!! edit=%s level=%s br=%s bits=%08b offset=%s ch=%s"
    //                    .format(numEdits, level, toUint(br), br.bits, br.offset.get, chunk));
    //
    //                while(level<5) {
    //                    level++;
    //                    if(level==5) {
    //                        writefln(" [%s] %s", level, (cast(M3Cell*)parents[level]).toString);
    //                    } else {
    //                        writefln(" [%s] %s", level, (cast(M3Branch*)parents[level]).toString);
    //                    }
    //                }
    //
    //                auto p = cast(M3Cell*)parents[5];
    //                writefln("parent: %s", p.toString);
    //                if(p.isSolid) writefln("SOLID");
    //                else if(p.isAir) writefln("AIR");
    //                else {
    //                    for(int i=0; i<8; i++) {
    //                        if(p.isBranch(i)) {
    //                            writefln("  [%s] %s ", i, p.getBranch(voxels.ptr, i).toString);
    //                        }
    //                    }
    //                }
    //                writefln("cell=%s", cast(ulong)parents[5]-cast(ulong)voxels.ptr);
    //
    //
    //                // 00010000 16388 (cell 3840)
    //                // 00010000 16392 (1) (L5)
    //                // 01010000 16420 (2) (l4)
    //                // 01010000 16412 (2) (l3)
    //                //
    //
    //
    //                expect(false);
    //            }
    //            for(auto i=0; i<8; i++) {
    //                if(br.isBranch(i)) {
    //                    if(level==2) {
    //
    //                    } else {
    //                        parents[level] = br;
    //                        followBranch(br, br.getBranch(voxels.ptr, i), level-1);
    //                    }
    //                }
    //            }
    //        }
    //    }
    //    for(int c=0; c<32768; c++) {
    //        M3Cell* cell = getRoot().getCell(voxels.ptr, c);
    //        for(auto i=0; i<8; i++) {
    //            if(!cell.isSolid && !cell.isAir) {
    //                expect(cell.offset.get < 250000, "edit=%s".format(numEdits));
    //                if(cell.isBranch(i)) {
    //                    parents[5] = cell;
    //                    followBranch(cell, cell.getBranch(voxels.ptr, i), 4);
    //                }
    //            }
    //        }
    //    }
    //}

    uint alloc(uint numBytes) {
        chat("  alloc(%s)", numBytes);
        int offset = allocator.alloc(numBytes, 4).as!int;
        if(offset==-1) {
            uint newSize = allocator.size().as!uint + BUFFER_INCREMENT;
            allocator.resize(newSize);
            voxels.length = newSize;
            assert(allocator.size()==newSize);
            assert(voxels.length==newSize);

            chat("  resize to %s", newSize);

            offset = allocator.alloc(numBytes, 4).as!int;

            expect(offset!=-1);
        }
        assert((offset%4)==0);
        chat("  offset=%s", offset);
        return offset;
    }
    void dealloc(uint offset, uint numBytes) {
        allocator.free(offset, numBytes);
    }

    void chat(A...)(lazy string fmt, lazy A args) {
        //if(chunk.pos==int3(0,0,1) && numEdits==2196) {
        //    writefln(format(fmt, args));
        //    flushConsole();
        //}
    }

    M3Root* getRoot() { return cast(M3Root*)voxels.ptr; }

    uint toUint(M3Cell* c)     { return cast(uint)(cast(ulong)c-cast(ulong)voxels.ptr); }
    uint toUint(M3Branch* b)   { return cast(uint)(cast(ulong)b-cast(ulong)voxels.ptr); }
    M3Branch* toBranch(uint o) { return cast(M3Branch*)(voxels.ptr+o); }
    M3Cell* toCell(uint o)     { return cast(M3Cell*)(voxels.ptr+o); }

    /// Get cell index (0-32767)
    uint getCellOct(uint3 pos) {
        uint3 p = pos & 0b11_1110_0000;
        /// x =           00_0001_1111 \
        /// y =           11_1110_0000  > cell = 0zzz_zzyy_yyyx_xxxx
        /// z =    0111_1100_0000_0000 /
        auto oct = (p.x>>>5) | p.y | (p.z<<5);
        assert(oct<32768);
        return oct;
    }
    /// Get branch/leaf index (0-7)
    uint getOct(uint3 pos, uint and, uint shift) {
        assert(popcnt(and)==1);
        assert((and>>shift)==1);
        /// For and==1:
        /// x = 0000_0001 \
        /// y = 0000_0001  >  oct = 0000_0zyx
        /// z = 0000_0001 /
        uint3 p = (pos & and)>>shift;
        auto oct = (p << uint3(0, 1, 2)).hadd();
        assert(oct<8);
        return oct;
    }
    void expand(M3Cell* cell, uint oct) {
        chat("  expand cell %s", oct);
        assert(cell.numBranches<8);

        /// If this is the first branch then alloc space
        if(cell.numBranches==0) {

            auto temp = toUint(cell);

            uint offset = alloc(8*M3Branch.sizeof);

            /// Refresh our cell ptr as it may have changed if voxels were resized
            cell = toCell(temp);

            cell.offset.set(offset/4);
        }
        cell.setToBranch(oct);

        auto branch = cell.getBranch(voxels.ptr, oct);
        branch.setToAir();
    }
    void expand(M3Branch* branch, uint oct, uint level) {
        chat("  expand branch level=%s oct=%s", level, oct);
        assert(branch.numBranches<8);

        uint elementSize = cast(uint)M3Branch.sizeof;
        if(level==1) {
            elementSize = cast(uint)M3Leaf.sizeof;
        }

        /// If this is the first branch then alloc space
        if(branch.numBranches==0) {

            auto temp = toUint(branch);

            uint offset = alloc(8*elementSize);

            /// Refresh our branch ptr as it may have changed if voxels were resized
            branch = toBranch(temp);

            branch.offset.set(offset/4);
        }
        branch.setToBranch(oct);

        if(level==1) {
            auto leaf = branch.getLeaf(voxels.ptr, oct);
            leaf.setToAir();
        } else {
            branch = branch.getBranch(voxels.ptr, oct);
            branch.setToAir();
        }
    }
    void collapse(M3Cell* cell) {
        assert(cell.bits==0xff);
        chat("  collapse cell");

        uint oldOffset = cell.offset.get()*4;
        uint oldSize   = 8*M3Branch.sizeof;

        cell.setToSolid();

        dealloc(oldOffset, oldSize);
    }
    void collapse(M3Branch* branch, uint level) {
        assert(branch.bits==0xff);
        chat("  collapse br L%s", level);

        uint oldOffset = branch.offset.get()*4;
        uint oldSize   = 8*(level==2 ? M3Leaf.sizeof : M3Branch.sizeof);

        branch.setToSolid();

        dealloc(oldOffset, oldSize);

        if(level < 4) {
            level++;
            auto upBranch = toBranch(branchOffsets[level]);
            if(upBranch.allBranchesAreSolid(voxels.ptr)) {
                collapse(upBranch, level);
            }
        } else if(level==4) {
            auto cell = toCell(cellOffset);
            if(cell.allBranchesAreSolid(voxels.ptr)) {
                collapse(cell);
            }
        }
    }
    void unsetVoxel(uint3 offset) {
        chat("%s: unsetVoxel(%s)", toString(), offset);
        auto root = getRoot();
        if(root.isAir) return;

        uint cellOct = getCellOct(offset);
        auto cell    = root.getCell(voxels.ptr, cellOct);
        if(cell.isAir) return;

        uint and = 0b00_0001_0000;

        assert(false, "Implement me");
    }
    void setVoxel(uint3 offset) {
        chat("%s: EDIT %s setVoxel(%s) root:%s", toString(), numEdits, offset, getRoot().toString());

        /// Create root cells if chunk is AIR
        if(getRoot().isAir) {
            expect(voxels.length==8);
            expect(allocator.numBytesUsed==8, "%s".format(allocator.numBytesUsed));
            expect(8==alloc(M3Cell.sizeof*M3_CELLS_PER_CHUNK));

            /// Convert to cells
            voxels[8..8+M3Cell.sizeof*M3_CELLS_PER_CHUNK] = 0;

            getRoot().flag=M3Flag.MIXED;

            expect(allocator.numBytesUsed==M3_ROOT_SIZE, "%s".format(allocator.numBytesUsed));
        }

        /// Layer 5 - cell
        uint oct   = getCellOct(offset);
        auto cell  = getRoot().getCell(voxels.ptr, oct);
        cellOffset = toUint(cell);

        chat("  oct %s cell %s", oct, cell.toString);
        if(cell.isSolid) return;

        /// Level 4
        oct = getOct(offset, 0b00_0001_0000, 4);
        chat("  L4 oct %s", oct);
        if(cell.isAir(oct)) {
            expand(cell, oct);
            /// voxels.ptr may have changed
            cell = toCell(cellOffset);
        }
        auto branch = cell.getBranch(voxels.ptr, oct);
        chat("  L4branch = %s", branch.toString);
        if(branch.isSolid) return;

        branchOffsets[4] = toUint(branch);

        /// Levels 3 and 2
        uint and = 0b00_0000_1000;
        for(uint level = 3; level>1; level--) {

            oct = getOct(offset, and, level);
            chat("  L%s oct %s", level, oct);
            if(branch.isAir(oct)) {
                expand(branch, oct, level);
                /// voxels.ptr may have changed
                branch = toBranch(branchOffsets[level+1]);
            }
            branch = branch.getBranch(voxels.ptr, oct);
            chat("  L%sbranch = %s", level, branch.toString);
            if(branch.isSolid) return;

            branchOffsets[level] = toUint(branch);

            and >>= 1;
        }

        /// Level 1
        oct = getOct(offset, 0b00_0000_0010, 1);
        chat("  L1 oct %s", oct);
        if(branch.isAir(oct)) {
            expand(branch, oct, 1);
            /// voxels.ptr may have changed
            branch = toBranch(branchOffsets[2]);
        }

        auto leaf = branch.getLeaf(voxels.ptr, oct);

        /// set the voxel
        oct = getOct(offset, 0b00_0000_0001, 0);
        chat("  L0 oct %s", oct);
        leaf.setVoxel(oct);

        if(leaf.isSolid) {
            chat("  leaf is solid");
            if(branch.allLeavesAreSolid(voxels.ptr)) {
                chat("  allLeavesAreSolid");
                collapse(branch, 2);
            }
        }
    }
}
