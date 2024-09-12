module blockie.model.ChunkEditView;

import blockie.model;

abstract class ChunkEditView {
public:
    final Chunk getChunk() { return chunk; }
    final chunkcoords pos() { return chunk.pos; }

    void beginTransaction(Chunk chunk) {
        throwIf(chunk is null);
        this.chunk = chunk;
    }

    abstract void voxelEditsCompleted();
    abstract void commitTransaction();
    abstract void setVoxel(uint3 offset, ubyte value);

    abstract bool isAir();
    abstract bool isAirCell(uint cellIndex);

    abstract void setChunkDistance(DFieldsBi f);

    // These might need some refactoring
    abstract void setCellDistance(uint cell, uint x, uint y, uint z);
    abstract void setCellDistance(uint cell, DFieldsBi f);
protected:
    Chunk chunk;
}

///
/// Used by distance field calculations. Pretends to be an air chunk at infinite pos.
///
final class FakeEditView : ChunkEditView {
private:
    bool setToAir = false;
public:
    this(bool setToAir = true) {
        this.setToAir = setToAir;
    }
    override bool isAir()              { return setToAir; }
    override bool isAirCell(uint cell) { return true; }

    override void beginTransaction(Chunk chunk) { throw new Error("Abstract"); }
    override void voxelEditsCompleted() { throw new Error("Abstract"); }
    override void commitTransaction() { throw new Error("Abstract"); }
    override void setVoxel(uint3 offset, ubyte value) { throw new Error("Abstract"); }
    override void setChunkDistance(DFieldsBi f) { throw new Error("Abstract"); }
    override void setCellDistance(uint cell, uint x, uint y, uint z) { throw new Error("Abstract"); }
    override void setCellDistance(uint cell, DFieldsBi df) { throw new Error("Abstract"); }
}
