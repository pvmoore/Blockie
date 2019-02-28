module blockie.model4.M4Chunk;

import blockie.all;

///
/// Chunk:
///     Root:
///         Flag (1 bytes)
///         Chunk distances (3 bytes)
///         Cell info    : 32^^3 cells (Each cell is 1 bit flag + 1 bit bit counts (total 65536 bytes)
///     Pixel arrays : 0 to 32768 pixel arrays
///
/// Pixel array: 32768 bits (4096 bytes)

/// Problem: The resulting memory usage is too high. Scene 4 uses 2 GB !!
///
///

final class M4Chunk : Chunk {
public:
    this(chunkcoords coords) {
        super(coords);

        /// Set to air
        voxels.length = 4;
        auto r = root();
        r.flag = M4Root.Flag.AIR;
        r.distance.set(0,0,0);
    }

    override bool isAir() { return root().isAir(); }

    override bool isAirCell(uint cell) {
        assert(cell<M4_CELLS_PER_CHUNK);

        return root().cells[cell].isAir;
    }
    override void setDistance(ubyte x, ubyte y, ubyte z) {
        root().distance.set(x,y,z);
    }
    override void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z) {
        assert(cell < M4_CELLS_PER_CHUNK);
        assert(!isAir);
        assert(root().cells[cell].isAir);

        root().cells[cell].distance.set(x,y,z);
    }

    M4Root* root() { return cast(M4Root*)voxels.ptr; }
}
//======================================================================================
/// If flag==AIR -> root size is 4
/// else         -> root size is 4 + M4_CELLS_PER_CHUNK*4
///
align(1) struct M4Root { align(1):
    enum Flag : ubyte { AIR=0, CELLS=1 }
    static assert(M4Root.sizeof == 4 + M4_CELLS_PER_CHUNK*4);

    Flag flag;
    M4Distance distance; /// if flag==AIR
    M4Cell[M4_CELLS_PER_CHUNK] cells;
    //-------------------------------------------------------------------
    bool isAir()   { return flag==Flag.AIR; }
    bool isCells() { return flag==Flag.CELLS; }

    bool allCellsAreAir() {
        foreach(c; cells) if(!c.isAir) return false;
        return true;
    }
    void setToCells() {
        this.flag = Flag.CELLS;
        this.distance.set(0,0,0);
    }
    string toString() { return "Root(%s)".format(isAir?"AIR":"CELLS"); }
}
align(1) struct M4Cell { align(1):
    enum Flag : ubyte { AIR=0, SOLID_PIXELS=1, MIXED_PIXELS=2 }
    static assert(M4Cell.sizeof == 4);

    Flag flag = Flag.AIR;
    union {
        M4Distance distance;/// if isAir
        M4Offset offset;    /// if isMixed
    }
    //-------------------------------------------------------------------
    bool isAir()   { return flag==Flag.AIR; }
    bool isSolid() { return flag==Flag.SOLID_PIXELS; }
    bool isMixed() { return flag==Flag.MIXED_PIXELS; }

    void setToAir() {
        this.flag = Flag.AIR;
        this.distance.set(0,0,0);
    }
    void setToSolidPixels() {
        this.flag = Flag.SOLID_PIXELS;
        this.distance.set(0,0,0);
    }
    void setToMixedPixels(uint offset) {
        this.flag = Flag.MIXED_PIXELS;
        this.offset.set(offset);
    }

    string toString() {
        return "Cell(%s)".format(isAir   ? "AIR":
                                 isSolid ? "SOLID"
                                         : "PIXELS@%s".format(offset));
    }
}
/+
align(1) struct M4Root { align(1):
    M4Flag flag;
    M4Distance distance;    /// if flag==AIR
    uint[M4_CELLS_PER_CHUNK/32] cellBits;       // 1024 uints, 4096 bytes, 32768 bits

    /// eg. [0] = popcnt(cellBits[0])
    ///     [1] = popcnt(cellBits[0]) + popcnt(cellBits[1])
    ///     [2] = popcnt(cellBits[0]) + popcnt(cellBits[1] + popcnt(cellBits[2])
    ///  [1023] = total num bits set
    uint[M4_CELLS_PER_CHUNK/32] cellPopCounts;  // 1024 uints

    static assert(M4Root.sizeof == 4 + 4096 + 4096);

    bool isAir()   { return flag==M4Flag.AIR; }
    bool isMixed() { return flag==M4Flag.MIXED; }

    bool isAir(uint cell) {
        assert(cell<M4_CELLS_PER_CHUNK);

        const b = cellBits[cell>>>5];
        const r = cell&31;
        return (b & (1<<r)) == 0;
    }
    ubyte* pixels(ubyte[] voxels, uint cell) {
        return voxels.ptr + pixelsOffset(cell);
    }
    bool allCellsAreAir() {
        return cellBits.onlyContains(0);
    }
    void setToAir(ref ubyte[] voxels, uint cell) {
        assert(cell<M4_CELLS_PER_CHUNK);
        assert(!isAir(cell));

        /// Clear bit
        const r = cell&31;
        cellBits[cell>>>5] &= ~((1u<<r));

        /// Update popcnts
        for(auto i=cell>>>5; i<cellPopCounts.length; i++) {
            assert(cellPopCounts[i]!=0);
            cellPopCounts[i]--;
        }

        /// Shift subsequent pixels left
        auto num = totalPopCount() - popCount(cell);

        if(num > 0) {
            import core.stdc.string : memmove;

            auto dest = pixels(voxels, cell);
            memmove(dest, dest + M4_PIXELS_SIZE, num*M4_PIXELS_SIZE);
        }

        /// decrease voxels array
        voxels.length -= M4_PIXELS_SIZE;
    }
    void setToPixels(ref ubyte[] voxels, uint cell) {
        assert(cell<M4_CELLS_PER_CHUNK);
        assert(isAir(cell));

        /// Set bit
        const r = cell&31;
        cellBits[cell>>>5] |= ~((1u<<r));

        /// Update popcnts
        for(auto i=cell>>>5; i<cellPopCounts.length; i++) {
            cellPopCounts[i]++;
        }

        /// Shift subsequent pixels right
        import core.stdc.string : memmove, memset;

        auto num    = (totalPopCount()-1) - popCount(cell);
        auto offset = pixels(voxels, cell);

        /// extend voxels array
        voxels.length += M4_PIXELS_SIZE;

        if(num > 0) {
            memmove(offset + M4_PIXELS_SIZE, offset, num*M4_PIXELS_SIZE);
        }

        /// Zero pixels
        memset(offset, 0, M4_PIXELS_SIZE);
    }
    string toString() { return "%s pixel cells".format(totalPopCount()); }
private:
    uint pixelsOffset(uint cell) {
        assert(cell<M4_CELLS_PER_CHUNK);

        return M4_ROOT_SIZE + (popCount(cell) * M4_PIXELS_SIZE); // pixel array is bits
    }
    /// Returns num bits set in cellBits between bit 0 and bit _oct_
    uint popCount(uint cell) {
        assert(cell<M4_CELLS_PER_CHUNK);

        if(cell-- == 0) return 0;

        uint o = cell>>>5;
        uint i = o==0 ? 0 : cellPopCounts[o-1];

        const r = cell&31;
        if(r!=0) {
            const mask = 0xffff_ffff >>> (32-r);
            i += popcnt(cellBits[o] & mask);
        }
        return i;
    }
    uint totalPopCount() {
        return cellPopCounts[$-1];
    }
    uint numAirCells() {
        return M4_CELLS_PER_CHUNK - cellPopCounts[$-1];
    }
}
+/
//------------------------------------------------------------------------------------
align(1) struct M4Offset { align(1):
    ubyte[3] v;
    static assert(M4Offset.sizeof==3);

    uint get() const { return (v[2]<<16) | (v[1]<<8) | v[0]; }
    void set(uint o) {
        assert(o <= 0x00ff_ffff);
        v[0] = cast(ubyte)(o&0xff);
        v[1] = cast(ubyte)((o>>8)&0xff);
        v[2] = cast(ubyte)((o>>16)&0xff);
    }
    string toString() const { return "%s".format(get()*4); }
}
align(1) struct M4Distance { align(1):
    ubyte x,y,z;
    static assert(M4Distance.sizeof==3);

    void set(ubyte x, ubyte y, ubyte z) {
        this.x = x; this.y = y; this.z = z;
    }
    string toString() const { return "%s,%s,%s".format(x,y,z); }
}