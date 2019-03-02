module blockie.model.ChunkEditView;

import blockie.all;

abstract class ChunkEditView {
    ChunkEditView beginTransaction(Chunk chunk);
    ChunkEditView commitTransaction();

    abstract ChunkEditView setVoxel(uint3 offset, ubyte value);

    abstract bool isAir();
    abstract bool isAirCell(uint cellIndex);
    abstract void setDistance(ubyte x, ubyte y, ubyte z);
    abstract void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z);
    abstract void setCellDistance(uint cell, DFieldsBi df);
}
