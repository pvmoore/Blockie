module blockie.model.ChunkEditView;

import blockie.model;

interface ChunkEditView {
    void beginTransaction(Chunk chunk);
    void voxelEditsCompleted();
    void commitTransaction();
    void setVoxel(uint3 offset, ubyte value);

    Chunk getChunk();
    chunkcoords pos();

    bool isAir();
    bool isAirCell(uint cellIndex);
    void setChunkDistance(DFieldsBi f);
    void setCellDistance(uint cell, uint x, uint y, uint z);
    void setCellDistance(uint cell, DFieldsBi f);
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
    bool isAir()              { return setToAir; }
    bool isAirCell(uint cell) { return true; }
    chunkcoords pos()         { return chunkcoords(int.min); }

    Chunk getChunk() { throw new Error("Abstract"); }
    void beginTransaction(Chunk chunk) { throw new Error("Abstract"); }
    void voxelEditsCompleted() { throw new Error("Abstract"); }
    void commitTransaction() { throw new Error("Abstract"); }
    void setVoxel(uint3 offset, ubyte value) { throw new Error("Abstract"); }
    void setChunkDistance(DFieldsBi f) { throw new Error("Abstract"); }
    void setCellDistance(uint cell, uint x, uint y, uint z) { throw new Error("Abstract"); }
    void setCellDistance(uint cell, DFieldsBi df) { throw new Error("Abstract"); }
}
