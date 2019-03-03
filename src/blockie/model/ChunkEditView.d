module blockie.model.ChunkEditView;

import blockie.all;

interface ChunkEditView {
    void beginTransaction(Chunk chunk);
    void commitTransaction();
    void setVoxel(uint3 offset, ubyte value);

    Chunk getChunk();
    chunkcoords pos();

    bool isAir();
    bool isAirCell(uint cellIndex);
    void setDistance(ubyte x, ubyte y, ubyte z);
    void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z);
    void setCellDistance(uint cell, DFieldsBi df);
}

///
/// Used by distance field calculations. Pretends to be an air chunk at infinite pos.
///
final class FakeEditView : ChunkEditView {
    bool isAir()              { return true; }
    bool isAirCell(uint cell) { return true; }
    chunkcoords pos()         { return chunkcoords(int.min); }

    Chunk getChunk() { throw new Error("Abstract"); }
    void beginTransaction(Chunk chunk) { throw new Error("Abstract"); }
    void commitTransaction() { throw new Error("Abstract"); }
    void setVoxel(uint3 offset, ubyte value) { throw new Error("Abstract"); }
    void setDistance(ubyte x, ubyte y, ubyte z) { throw new Error("Abstract"); }
    void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z) { throw new Error("Abstract"); }
    void setCellDistance(uint cell, DFieldsBi df) { throw new Error("Abstract"); }
}
