module blockie.model4.M4ChunkEditView;

import blockie.all;

final class M4ChunkEditView : ChunkEditView {
private:
    const uint BUFFER_INCREMENT = 1024*512;
    StopWatch watch;
    M4Chunk chunk;
    ubyte[] voxels;
    uint version_;
    Allocator_t!uint allocator;
    M4Optimiser optimiser;

    uint numEdits;
public:
    uint[uint] cellOffsets;     // key = cell
    ushort[8^^M4_CELL_LEVEL] cellDistances;

    this() {
        this.allocator = new Allocator_t!uint(0);
        this.optimiser = new M4Optimiser(this);
    }
    M4Root* root() { return cast(M4Root*)voxels.ptr; }

    override Chunk getChunk() {
        return chunk;
    }
    override chunkcoords pos() {
        return chunk.pos;
    }
    override void beginTransaction(Chunk chunk) {
        expect(chunk !is null);

        this.chunk = cast(M4Chunk)chunk;

        convertToEditable();
    }
    override void voxelEditsCompleted() {
       // writefln("%s Edits completed. %s cells", pos, cellOffsets.length); flushConsole();
        root().recalculateFlags();
        root().calculateLevel1To6Bits();
        root().calculateL7Popcounts();
    }
    override void commitTransaction() {

        auto optVoxels = optimiser.optimise(voxels[0..allocator.offsetOfLastAllocatedByte+1]);

        /// Write voxels back to chunk
        uint ver = chunk.atomicUpdate(version_, optVoxels);
        if(ver!=version_+1) {
            /// Stale
            chat("M4ChunkEditView: %s is stale", chunk);
        } else {
            log("Chunk %s updated to version %s", chunk, ver);
        }

        /// Free everything
        allocator.freeAll();
        cellOffsets.clear();
        voxels = null;
    }
    override void setVoxel(uint3 offset, ubyte value) {
        watch.start();
        assert(chunk !is null);

        if(value==0) {
            unsetVoxel(offset);
        } else{
            setVoxel(offset);
        }

        numEdits++;
        watch.stop();
    }
    override bool isAir() {
        return root().isAir();
    }
    override bool isAirCell(uint cell) {
        return root().isAirCell(cell, M4_CELL_LEVEL);
    }
    override void setChunkDistance(DFieldsBi f) {
        root().distance.set(f);
    }
    override void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z) {
        cellDistances[cell] = (x | (y<<5) | (z<<10)).as!ushort;
        //writefln("%s -> %s -> %s,%s,%s", cell, cellDistances[cell],
        //    cellDistances[cell] & 31,
        //    (cellDistances[cell]>>5) & 31,
        //    (cellDistances[cell]>>10) & 31
        //);
    }
    override void setCellDistance(uint cell, DFieldsBi f) {
        throw new Error("BiDir cell distances not supported");
    }
    override string toString() {
        return "View %s".format(chunk.pos);
    }
private:
    void convertToEditable() {
        /// Initially only allocate the exact number of voxels used
        /// in case we don't actually make any edits which is likely
        this.voxels = new ubyte[chunk.getVoxelsLength];
        this.allocator.resize(chunk.getVoxelsLength);

        /// We can only handle air chunks so far
        expect(voxels.length==8);

        chunk.atomicCopyTo(version_, this.voxels);
        expect(version_!=0, "%s version_ is %s".format(chunk, version_));

        alloc(chunk.getVoxelsLength);

        expect(allocator.numBytesUsed==chunk.getVoxelsLength);
        expect(allocator.numBytesFree==0);

        // todo - set cellOffsets here
    }
    void chat(A...)(lazy string fmt, lazy A args) {
        //if(chunk.pos==int3(0,0,0)) { //&& numEdits<0) {
        //    writefln(format(fmt, args));
        //    flushConsole();
        //}
    }
    uint alloc(uint numBytes) {
        //chat("  alloc(%s)", numBytes);
        int offset = allocator.alloc(numBytes);
        if(offset==-1) {
            uint newSize = allocator.length + numBytes + BUFFER_INCREMENT;
            allocator.resize(newSize);
            voxels.length = newSize;
            expect(allocator.length==newSize);
            expect(voxels.length==newSize);

            //chat("  resize to %s", newSize);

            offset = allocator.alloc(numBytes);

            expect(offset!=-1);
        }
        assert((offset%4)==0);
        //chat("  offset=%s", offset);
        return offset;
    }
    void dealloc(uint offset, uint numBytes) {
        chat("free(%s,%s)", offset, numBytes);
        allocator.free(offset, numBytes);
    }
    M4Root* getRoot() { return cast(M4Root*)voxels.ptr; }

    /// Get cell index (0-2_097_151)
    uint getCellOct(uint3 pos) {
        expect(M4_OCTREE_ROOT_BITS==7);

        uint3 p = pos &     0b11_1111_1000;
        /// x =               00_0111_1111 \
        /// y =          11_1111_1000_0000  > cell = z_zzzz_zzyy_yyyy_yxxx_xxxx
        /// z = 1_1111_1100_0000_0000_0000 /
        auto oct = (p.x>>>3) | (p.y<<4) | (p.z<<11);
        expect(oct<2_097_152);
        return oct;
    }
    /// Get branch/leaf index (0-7)
    uint getOct(uint3 pos, uint and, uint shift) {
        expect((and>>shift)==1);

        /// For and==1:
        /// x = 0000_0001 \
        /// y = 0000_0001  >  oct = 0000_0zyx
        /// z = 0000_0001 /
        uint3 p = (pos & and)>>shift;
        auto oct = (p << uint3(0, 1, 2)).hadd();
        expect(oct<8);
        return oct;
    }

    void unsetVoxel(uint3 offset) {
        chat("%s: unsetVoxel(%s)", toString(), offset);
        auto root = getRoot();
        if(root.isAir) return;

        expect(false, "Implement me");
    }
    void setVoxel(uint3 offset) {
        chat("%s: EDIT %s setVoxel(%s) root:%s", toString(), numEdits, offset, getRoot().toString());

        uint cellOct;
        uint branchOct;
        uint leafOct;

        M4Cell* getCell() {
            return cast(M4Cell*)(voxels.ptr+cellOffsets[cellOct]);
        }
        M4Branch* getBranch() {
            auto br = cast(M4Branch*)(voxels.ptr + getCell().offset.get());
            br += branchOct;
            return br;
        }
        M4Leaf* getLeaf() {
            auto leaf = cast(M4Leaf*)(voxels.ptr + getBranch().offset.get());
            leaf += leafOct;
            return leaf;
        }

        /// Create root if chunk is AIR
        if(getRoot().isAir) {
            expect(voxels.length==8);
            expect(allocator.numBytesUsed==8, "%s".format(allocator.numBytesUsed));
            expect(8==alloc(M4_ROOT_SIZE-8));

            /// This chunk is now OCTREES
            voxels[0..M4_ROOT_SIZE] = 0;
            getRoot().setToOctrees();

            chat("Converted chunk to OCTREES");
            expect(allocator.numBytesUsed==M4_ROOT_SIZE);
        }

        /// cellOct  (11_1111_1000) --> M4Cell      --> point to 0..8 M4Branch
        /// branchOct(         100) --> M4Branch    --> point to 0..8 M4Leaf
        /// leafOct  (          10) --> M4Leaf      --> Each leaf contains 8 bits
        /// voxelOct (           1) --> Bit in M4Leaf

        cellOct = getCellOct(offset);
        chat("cell = %s", cellOct);

        if(getRoot().isAirCell(cellOct)) {
            /// Create space for a non-air cell
            auto co = alloc(M4Cell.sizeof);

            /// Set cell offset
            expect(cellOct !in cellOffsets);
            cellOffsets[cellOct] = co;

            /// Create space for 8 branches
            auto po = alloc(8*M4Branch.sizeof);

            /// Zero mem
            voxels[po..po+8*M4Branch.sizeof] = 0;

            /// Set cell data
            getCell().bits = 0;
            getCell().offset.set(po);

            getRoot().setCellToNonAir(cellOct);

            chat("  Creating cell %s (offset = %s)", cellOct, po);
        }

        /// Branch 0b100
        branchOct = getOct(offset, 0b100, 2);
        getCell().setToBranches(branchOct);

        chat("  Branch oct = %s, bits = %s", branchOct, getCell().bits);

        //if(getBranch().isSolid) {
        //    expect(false);
        //    return;
        //}
        if(getBranch().isAir) {
            /// Create space for some leaves
            auto po = alloc(8*M4Leaf.sizeof);

            /// Set leaves offset
            getBranch().offset.set(po);

            /// Zero mem
            voxels[po..po+8] = 0;

            chat("  Creating leaves for branch %s (offset = %s) bits=%s",
                branchOct, po, getBranch().bits);
        }


        /// Leaf 0b10
        leafOct = getOct(offset, 0b10, 1);
        chat("  Leaf oct = %s", leafOct);

        getBranch().setToLeaf(leafOct);


        /// Voxel 0b1
        auto leaf     = getLeaf();
        auto voxelOct = getOct(offset, 1, 0);
        chat("  Voxel oct = %s", voxelOct);

        leaf.setVoxel(voxelOct);
    }
}
