module blockie.model5.M5ChunkEditView;

import blockie.all;

final class M5ChunkEditView : ChunkEditView {
private:
    enum BUFFER_INCREMENT = 1024*512;
    Allocator_t!uint allocator;
    M5Optimiser optimiser;

    M5Chunk chunk;
    ubyte[] voxels;
    uint version_;

    uint[6] branchOffsets;
    uint cellOffset;

    uint numEdits;
    uint tempNumEdits;
    StopWatch watch;
public:
    this() {
        this.allocator = new Allocator_t!uint(0);
        this.optimiser = new M5Optimiser(this);
    }
    ubyte[] getVoxels()             { return voxels; }
    Allocator_t!uint getAllocator() { return allocator; }
    M5Root* root()                  { return cast(M5Root*)voxels.ptr; }

    override Chunk getChunk()  { return chunk; }
    override chunkcoords pos() { return chunk.pos; }

    override void beginTransaction(Chunk chunk) {
        expect(chunk !is null);

        this.chunk = cast(M5Chunk)chunk;

        convertToEditable();
    }
    override void voxelEditsCompleted() {
        root().allEditsComplete(root().as!(ubyte*));
    }
    override void commitTransaction() {

        auto optVoxels = optimiser.optimise(voxels, allocator.offsetOfLastAllocatedByte+1);

        allocator.freeAll();

        /// Write voxels back to chunk
        uint ver = chunk.atomicUpdate(version_, optVoxels);
        if(ver!=version_+1) {
            /// Stale
            log("M5ChunkEditView: %s is stale", chunk);
        } else {
            log("Chunk %s updated to version %s", chunk, ver);
        }
    }
    override void setVoxel(uint3 offset, ubyte value) {
        ASSERT(chunk !is null);

        if(value==0) {
            unsetVoxel(offset);
        } else{
            setVoxel(offset);
        }
        numEdits++;
        //writefln("edit %s", numEdits); flushConsole();
    }
    override bool isAir() {
        return root().isAir();
    }
    override bool isAirCell(uint cellIndex) {
        ASSERT(cellIndex<M5_CELLS_PER_CHUNK);
        return root().cells[cellIndex].isAir();
    }
    override void setChunkDistance(DFieldsBi f) {
        root().distance.set(f);
    }
    override void setCellDistance(uint cell, uint x, uint y, uint z) {
        ASSERT(cell<M5_CELLS_PER_CHUNK);

        auto c = root().getCell(voxels.ptr, cell);
        ASSERT(!isAir);
        ASSERT(voxels.length>4);
        ASSERT(c.isAir);

        c.distance.set(x,y,z);
    }
    override void setCellDistance(uint cell, DFieldsBi f) {
        // Max = 31
        uint convert(int v) { return min(v, 31); }

        setCellDistance(cell,
            (convert(f.x.up)<<5) | convert(f.x.down),
            (convert(f.y.up)<<5) | convert(f.y.down),
            (convert(f.z.up)<<5) | convert(f.z.down)
        );
    }
    override string toString() {
        return "View %s".format(chunk.pos);
    }
private:
    void chat(A...)(lazy string fmt, lazy A args) {
        //if(chunk.pos==int3(0,0,1) &&
        // if(numEdits==4_286_240) {
        //     writefln(format(fmt, args));
        //     flushConsole();
        // }
    }
    void convertToEditable() {
        /// Initially only allocate the exact number of voxels used
        /// in case we don't actually make any edits which is likely
        this.voxels = new ubyte[chunk.getVoxelsLength];
        this.allocator.resize(chunk.getVoxelsLength);

        chunk.atomicCopyTo(version_, this.voxels);
        ASSERT(version_!=0, "%s version_ is %s".format(chunk, version_));

        alloc(chunk.getVoxelsLength);

        ASSERT(allocator.numBytesUsed==chunk.getVoxelsLength);
        ASSERT(allocator.numBytesFree==0);
    }
    uint alloc(uint numBytes) {
        chat("  alloc(%s)", numBytes);
        int offset = allocator.alloc(numBytes, 4);
        if(offset==-1) {
            auto oldSize = voxels.length;
            uint newSize = allocator.length + BUFFER_INCREMENT;
            allocator.resize(newSize);
            voxels.length = newSize;
            ASSERT(allocator.length==newSize);
            ASSERT(voxels.length==newSize);

            chat("  resize to %s (from %s)", newSize, oldSize);

            offset = allocator.alloc(numBytes, 4);

            expect(offset!=-1);
        }
        ASSERT(offset < voxels.length);
        ASSERT((offset%4)==0);
        chat("  offset=%s", offset);

        /* Set to zeroes */
        voxels[offset..offset+numBytes] = 0;

        return offset;
    }
    // void dealloc(uint offset, uint numBytes) {
    //     allocator.free(offset, numBytes);
    // }
    uint toUint(void* c) {
        return cast(uint)(cast(ulong)c-cast(ulong)voxels.ptr);
    }
    M5SubCell1* toM5SubCell1(uint o) {
        return cast(M5SubCell1*)(voxels.ptr+o);
    }
    M5SubCell2* toM5SubCell2(uint o) {
        return cast(M5SubCell2*)(voxels.ptr+o);
    }
    M5SubCell3* toM5SubCell3(uint o) {
        return cast(M5SubCell3*)(voxels.ptr+o);
    }
    uint getOct_11_1100_0000(uint3 pos) {
        uint3 p = pos & 0b_0011_1100_0000;
        /// x =            0000_0000_1111 \
        /// y =            0000_1111_0000  > cell = zzzz_yyyy_xxxx
        /// z =            1111_0000_0000 /
        auto oct = (p.x>>>6) | (p.y>>>2) | (p.z<<2);
        ASSERT(oct<4096);
        return oct;
    }
    uint getOct_00_0011_0000(uint3 pos) {
        uint3 p = pos & 0b_0011_0000;
        /// x =            0000_0011 \
        /// y =            0000_1100  > cell = 00zz_yyxx
        /// z =            0011_0000 /
        auto oct = (p.x>>>4) | (p.y>>>2) | (p.z);
        ASSERT(oct<64);
        return oct;
    }
    uint getOct_00_0000_1100(uint3 pos) {
        uint3 p = pos & 0b_0000_1100;
        /// x =            0000_0011 \
        /// y =            0000_1100  > cell = 00zz_yyxx
        /// z =            0011_0000 /
        auto oct = (p.x>>>2) | (p.y) | (p.z<<2);
        ASSERT(oct<64);
        return oct;
    }
    uint getOct_00_0000_0010(uint3 pos) {
        uint3 p = pos & 0b_0000_0010;
        /// x =            0000_0001 \
        /// y =            0000_0010  > cell = 0000_0zyx
        /// z =            0000_0100 /
        auto oct = (p.x>>>1) | (p.y) | (p.z<<1);
        ASSERT(oct<8);
        return oct;
    }
    uint getOct_00_0000_0001(uint3 pos) {
        uint3 p = pos & 0b_0000_0001;
        /// x =            0000_0001 \
        /// y =            0000_0010  > cell = 0000_0zyx
        /// z =            0000_0100 /
        auto oct = (p.x) | (p.y<<1) | (p.z<<2);
        ASSERT(oct<8);
        return oct;
    }
    M5SubCell1* expand(M5SubCell1* cell, uint oct) {
        chat("  expand M5SubCell1 %s", oct);
        ASSERT(oct<64);

        /// If this is the first branch then alloc space
        if(cell.offset.get()==0) {

            /// Allocate space and refresh our cell ptr as it may have changed if voxels were resized
            auto temp   = toUint(cell);
            uint offset = alloc(64*M5SubCell2.sizeof);

            cell = toM5SubCell1(temp);

            cell.offset.set(offset/4);
        }
        cell.setToBranch(oct);

        return cell;
    }
    M5SubCell2* expand(M5SubCell2* cell, uint oct) {
        chat("  expand M5SubCell2 %s", oct);
        ASSERT(oct<64);

        /// If this is the first branch then alloc space
        if(cell.offset.get()==0) {

            /// Allocate space and refresh our cell ptr as it may have changed if voxels were resized
            auto temp   = toUint(cell);
            uint offset = alloc(64*M5SubCell3.sizeof);

            cell = toM5SubCell2(temp);

            cell.offset.set(offset/4);
        }
        cell.setToBranch(oct);

        return cell;
    }
    M5SubCell3* expand(M5SubCell3* cell, uint oct) {
        chat("  expand M5SubCell3 %s", oct);
        ASSERT(oct<8);

        /// If this is the first branch then alloc space
        if(cell.offset.get()==0) {

            // Alloc space for 8 leaves
            // and refresh our ptr as it may have changed if voxels were resized
            auto temp   = toUint(cell);
            uint offset = alloc(8*M5Leaf.sizeof);

            cell = toM5SubCell3(temp);

            cell.offset.set(offset/4);
        }

        cell.setToBranch(oct);

        return cell;
    }
    void unsetVoxel(uint3 offset) {
        throw new Error("Not implemented");
    }
    void setVoxel(uint3 offset) {
        chat("%s: EDIT %s setVoxel(%s) root:%s", toString(), numEdits, offset, root().toString());

        /* Create root cells if chunk is AIR */
        if(root().isAir) {
            ASSERT(voxels.length==8);
            ASSERT(allocator.numBytesUsed==8, "%s".format(allocator.numBytesUsed));
            ASSERT(8==alloc(M5SubCell1.sizeof*M5_CELLS_PER_CHUNK));

            /// Convert to empty M5Cell64_1s
            //voxels[8..8+M5SubCell1.sizeof*M5_CELLS_PER_CHUNK] = 0;

            root().flag = M5Flag.OCTREES;

            ASSERT(allocator.numBytesUsed==M5_ROOT_SIZE);
            chat("Root is now expanded to M5Cell64_1s");
        }

        // Get M5SubCell1
        auto oct          = getOct_11_1100_0000(offset);
        M5SubCell1* cell1 = root().getCell(voxels.ptr, oct);

        chat("  %s oct %s ", cell1.toString, oct);

        // Get M5SubCell2
        oct = getOct_00_0011_0000(offset);
        chat("  oct %s", oct);
        if(cell1.isAir(oct)) {
            cell1 = expand(cell1, oct);
        }

        M5SubCell2* cell2 = cell1.getCell(voxels.ptr, oct);
        chat("  %s oct %s", cell2.toString, oct);

        // Get M5SubCell3
        oct = getOct_00_0000_1100(offset);
        chat("  oct %s", oct);
        if(cell2.isAir(oct)) {
            cell2 = expand(cell2, oct);
        }
        M5SubCell3* cell3 = cell2.getCell(voxels.ptr, oct);
        chat("  %s oct %s", cell3.toString, oct);

        // Get M5Leaf
        oct = getOct_00_0000_0010(offset);
        chat("  oct %s", oct);
        if(cell3.isAir(oct)) {
            cell3 = expand(cell3, oct);
        }
        M5Leaf* leaf = cell3.getLeaf(voxels.ptr, oct);
        chat("  %s oct %s", leaf.toString, oct);

        /// The voxel
        oct = getOct_00_0000_0001(offset);
        chat("  oct %s", oct);
        leaf.setVoxel(oct);
    }
}
