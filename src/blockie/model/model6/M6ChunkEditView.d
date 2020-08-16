module blockie.model.model6.M6ChunkEditView;

import blockie.all;
///
/// Level   | Bits         |                 | Count         | Volume                 |
/// --------+--------------+-----------------+---------------+------------------------|
/// chunk   | 11_1111_1111 | 1 M6Root        |             1 | 1024^3 = 1,073,741,824 |
///  root   | 11_1110_0000 | 32768 M6Cells   |        32,768 |   32^3 =        32,768 |
///  leaves | 00_0001_1111 | 32768           |
final class M6ChunkEditView : ChunkEditView {
private:
    M6Optimiser optimiser;
    M6Chunk chunk;
    uint version_;
    uint numEdits;
    StopWatch watch;

    bool _isAir;
public:
    // Edited chunk voxels state.
    // Don't create M6Root until we need it because most ChunkEditViews will be AIR
    M6AirRoot airRoot;
    M6Root* mixedRoot;

    this() {
        this.optimiser = new M6Optimiser(this);
    }
    void beginTransaction(Chunk chunk) {
        expect(chunk !is null);

        this.chunk = cast(M6Chunk)chunk;

        convertToEditable();
    }
    void voxelEditsCompleted() {
        if(!_isAir) mixedRoot.recalculateFlags();
    }
    void commitTransaction() {

        auto optVoxels = optimiser.optimise();

        /// Write voxels back to chunk
        uint ver = chunk.atomicUpdate(version_, optVoxels);
        if(ver!=version_+1) {
            /// Stale
            this.log(" %s is stale", chunk);
        } else {
            this.log("Chunk %s updated to version %s", chunk, ver);
        }
    }
    void setVoxel(uint3 offset, ubyte value) {
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
    Chunk getChunk() {
        return chunk;
    }
    chunkcoords pos() {
        return chunk.pos;
    }

    bool isAir() {
        return _isAir;
    }
    bool isAirCell(uint cellIndex) {
        assert(cellIndex<M6_CELLS_PER_CHUNK, "%s".format(cellIndex));
        if(_isAir) return true;
        assert(mixedRoot);
        return mixedRoot.isAirCell(cellIndex);
    }
    void setChunkDistance(DFieldsBi f) {
        assert(_isAir);
        airRoot.distance.set(f);
    }
    void setCellDistance(uint cell, uint x, uint y, uint z) {
        assert(cell<M6_CELLS_PER_CHUNK);
        assert(!_isAir);
        assert(mixedRoot);
        assert(mixedRoot.isAirCell(cell));

        M6Cell* c = &mixedRoot.cells[cell];
        c.distance.set(x,y,z);
    }
    void setCellDistance(uint cell, DFieldsBi f) {
        // Max = 15
        int convert(int v) { return minOf(v, 15); }

        setCellDistance(cell,
            (convert(f.x.up)<<4) | convert(f.x.down),
            (convert(f.y.up)<<4) | convert(f.y.down),
            (convert(f.z.up)<<4) | convert(f.z.down)
        );
    }
    override string toString() {
        return "View %s".format(chunk.pos);
    }
private:
    void convertToEditable() {
        auto voxels = new ubyte[chunk.getVoxelsLength];

        chunk.atomicCopyTo(version_, voxels);
        expect(version_!=0, "%s version_ is %s".format(chunk, version_));

        /// TODO - handle non air chunks
        expect(chunk.isAir());
        expect(chunk.voxels.length==8);

        this._isAir = true;
        expect(airRoot.flag == M6Flag.AIR);
    }
    /** Get cell index (0-32767) */
    uint getCellOct(uint3 pos) {
        uint3 p = pos & 0b11_1110_0000;
        /// x =           00_0001_1111 \
        /// y =           11_1110_0000  > cell = zzz_zzyy_yyyx_xxxx
        /// z =    0111_1100_0000_0000 /
        auto oct = (p.x>>>5) | (p.y) | (p.z<<5);
        assert(oct<M6_CELLS_PER_CHUNK);
        return oct;
    }
    uint getVoxelOct(uint3 pos) {
        uint3 p  = pos & 0b00_0001_1111;
        auto oct = p.x | (p.y<<5) | (p.z<<10);
        assert(oct<M6_VOXELS_PER_CELL);
        return oct;
    }
    void unsetVoxel(uint3 offset) {
        todo();
    }
    void setVoxel(uint3 offset) {
        //chat("%s: EDIT %s setVoxel(%s) root:%s",
        //        toString(), numEdits, offset, root.toString());

        if(_isAir) {
            // convert to mixed root
            _isAir        = false;
            airRoot.flag  = M6Flag.MIXED;
            mixedRoot     = new M6Root;
            mixedRoot.flag = M6Flag.MIXED;
        }

        uint cellOct = getCellOct(offset);
        //chat("cell oct = %s", cellOct);

        if(mixedRoot.isAirCell(cellOct)) {
            // convert cell to M6MixedCell
            mixedRoot.cellFlags[cellOct] = M6CellFlag.MIXED;
        }

        M6MixedCell* cell = &mixedRoot.cells[cellOct].mixed;

        uint index = getVoxelOct(offset);
        //chat("voxel index = %s", index);

        cell.set(index, true);
        //chat("cell = %s", cell.toString());
    }
}