module blockie.model.ChunkEditView;

import blockie.all;

abstract class ChunkEditView {
    void beginTransaction(Chunk chunk);
    void commitTransaction();
    void setVoxel(uint3 offset, ubyte value);

    bool isAir();
    bool isAirCell(uint cellIndex);
    void setDistance(ubyte x, ubyte y, ubyte z);
    void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z);
    void setCellDistance(uint cell, DFieldsBi df);
}
