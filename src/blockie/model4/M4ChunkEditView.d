module blockie.model4.M4ChunkEditView;

import blockie.all;

final class M4ChunkEditView : ChunkEditView {
private:
    const uint BUFFER_INCREMENT = 10*1024*1024;
    M4Chunk chunk;
    ubyte[] voxels;
    uint version_;
    Allocator_t!uint allocator;
    M4Optimiser optimiser;

    uint numEdits;
    StopWatch watch;
public:
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

    }
    override void commitTransaction() {

        auto optVoxels = optimiser.optimise(voxels, allocator.offsetOfLastAllocatedByte+1);

        /// Write voxels back to chunk
        uint ver = chunk.atomicUpdate(version_, optVoxels);
        if(ver!=version_+1) {
            /// Stale
            chat("M4ChunkEditView: %s is stale", chunk);
        } else {
            chat("Chunk %s updated to version %s", chunk, ver);
        }
        allocator.freeAll();
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
    override bool isAir() { return root().isAir(); }

    override bool isAirCell(uint cell) {
        assert(cell<M4_CELLS_PER_CHUNK);

        return root().cells[cell].isAir;
    }
    override void setChunkDistance(DFieldsBi f) {
        root().distance.set(f);
    }
    override void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z) {
        assert(cell < M4_CELLS_PER_CHUNK);
        assert(!isAir);
        assert(root().cells[cell].isAir);

        root().cells[cell].distance.set(x,y,z);
    }
    override void setCellDistance(uint cell, DFieldsBi f) {

        // Max = 15
        int convert(int v) { return min(v, 15); }

        setCellDistance(cell,
            cast(ubyte)((convert(f.x.up)<<4) | convert(f.x.down)),
            cast(ubyte)((convert(f.y.up)<<4) | convert(f.y.down)),
            cast(ubyte)((convert(f.z.up)<<4) | convert(f.z.down))
        );
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

        chunk.atomicCopyTo(version_, this.voxels);
        expect(version_!=0, "%s version_ is %s".format(chunk, version_));

        alloc(chunk.getVoxelsLength);

        expect(allocator.numBytesUsed==chunk.getVoxelsLength);
        expect(allocator.numBytesFree==0);
    }
    void chat(A...)(lazy string fmt, lazy A args) {
        //if(chunk.pos==int3(0,0,0) && numEdits<0) {
        //    writefln(format(fmt, args));
        //    flushConsole();
        //}
    }
    uint alloc(uint numBytes) {
        chat("  alloc(%s)", numBytes);
        int offset = allocator.alloc(numBytes, 4);
        if(offset==-1) {
            uint newSize = allocator.length + BUFFER_INCREMENT;
            allocator.resize(newSize);
            voxels.length = newSize;
            expect(allocator.length==newSize);
            expect(voxels.length==newSize);

            chat("  resize to %s", newSize);

            offset = allocator.alloc(numBytes, 4);

            chat("offset = %s", offset);

            expect(offset!=-1);
        }
        assert((offset%4)==0);
        chat("  offset=%s", offset);
        return offset;
    }
    void dealloc(uint offset, uint numBytes) {
        chat("free(%s,%s)", offset, numBytes);
        allocator.free(offset, numBytes);
    }
    M4Root* getRoot() { return cast(M4Root*)voxels.ptr; }

    /// Get cell index (0-262144)
    uint getCell(uint3 pos) {
        uint3 p = pos & 0b11_1111_0000;
        /// x =           00_0011_1111 \
        /// y =         1111_1100_0000  > cell = zz_zzzz_yyyy_yyxx_xxxx
        /// z = 11_1111_0000_0000_0000 /
        auto oct = (p.x>>>4) | (p.y<<2) | (p.z<<8);
        expect(oct<262144);
        return oct;
    }
    /// Get pixel index (0-4095)
    uint getPixelOffset(uint3 pos) {
        /// x = 0000_1111 \
        /// y = 0000_1111  >  oct = zzzz_yyyy_xxxx
        /// z = 0000_1111 /
        uint3 p = pos & 15;
        auto oct = (p << uint3(0, 4, 8)).hadd();
        expect(oct<4096);
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

        /// Create root if chunk is AIR
        if(getRoot().isAir) {
            expect(voxels.length==4);
            expect(allocator.numBytesUsed==4, "%s".format(allocator.numBytesUsed));
            expect(4==alloc(M4_ROOT_SIZE-4));

            /// This chunk is now CELLS
            voxels[0..M4_ROOT_SIZE] = 0;
            getRoot().setToCells();

            chat("Converted chunk to CELLS");
            expect(allocator.numBytesUsed==M4_ROOT_SIZE, "%s".format(allocator.numBytesUsed));
        }

        auto cell = getCell(offset);
        chat("cell = %s", cell);

        if(getRoot().cells[cell].isSolid) {
            /// Nothing to do
            return;
        }
        if(getRoot().cells[cell].isAir) {
            /// This cell is now MIXED_PIXELS

            auto po = alloc(M4_PIXELS_SIZE)/4;

            getRoot().cells[cell].setToMixedPixels(po);

            chat("Created pixel array for cell %s", getRoot().cells[cell]);
        }

        auto o = getRoot().cells[cell].offset.get()*4;

        auto p = getPixelOffset(offset);
        auto b = p>>>3;
        auto r = p&7;

        chat("pixel = %s (%s -> %s:%s)", o, p, b, r);

        voxels[o+b] |= cast(ubyte)(1<<r);
        chat("voxels[%s] = %s", o+b, voxels[o+b]);
    }
}
