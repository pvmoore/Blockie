module blockie.model4.M4Optimiser;

import blockie.all;

final class M4Optimiser {
private:
    M4ChunkEditView view;
    ubyte[] voxels;
    uint voxelsLength;
public:
    this(M4ChunkEditView view) {
        this.view = view;
    }
    ubyte[] optimise(ubyte[] voxels, uint voxelsLength) {
        this.voxels       = voxels;
        this.voxelsLength = voxelsLength;

        /// This chunk is AIR. Nothing to do
        if(view.isAir) {
            return [M4Root.Flag.AIR,
                    view.root().distance.x,
                    view.root().distance.y,
                    view.root().distance.z];
        }

        writefln("Optimiser: Processing %s", view);

        auto optVoxels = rewriteVoxels();

        writefln("\tOptimised chunk %s %s --> %s (%.2f%%)", view.getChunk.pos,
            voxelsLength, optVoxels.length, optVoxels.length*100.0 / voxelsLength);

        return optVoxels;
    }
private:
    M4Root* srcRoot() { return cast(M4Root*)voxels.ptr; }

    /// 1) If flag==MIXED_PIXELS and cell is solid -> Set flag = SOLID_PIXELS and remove pixels
    /// 2) If flag==MIXED_PIXELS and cell is air -> Set flag = AIR and remove pixels
    /// 3) Remove any gaps
    ubyte[] rewriteVoxels() {

        auto newVoxels = new ubyte[voxelsLength];
        uint dest      = M4_ROOT_SIZE;

        M4Root* destRoot() {
            return cast(M4Root*)newVoxels.ptr;
        }
        bool pixelsAreAll1(ubyte* p) {
            return onlyContains(p, M4_PIXELS_PER_CELL/8, 0xff);
        }
        bool pixelsAreAll0(ubyte* p) {
            return onlyContains(p, M4_PIXELS_PER_CELL/8, 0);
        }
        void copyRoot() {
            newVoxels[0..dest] = voxels[0..dest];
        }
        void copyPixels(ubyte* src) {
            newVoxels[dest..dest+M4_PIXELS_SIZE] = src[0..M4_PIXELS_SIZE];
            dest += M4_PIXELS_SIZE;
        }

        copyRoot();

        auto airCellCount = 0;

        foreach(ref cell; destRoot().cells) {
            if(cell.isAir) {
                /// Nothing to do - no pixels
                airCellCount++;
            } else if(cell.isSolid) {
                /// Nothing to do - no pixels
            } else if(cell.isMixed) {
                auto ptr = voxels.ptr + (cell.offset.get()*4);
                if(pixelsAreAll0(ptr)) {
                    /// Set cell to air and don't copy pixels
                    cell.setToAir();

                } else if(pixelsAreAll1(ptr)) {
                    /// Set cell to solid and don't copy pixels
                    cell.setToSolidPixels();

                } else {
                    cell.offset.set(dest/4);
                    copyPixels(ptr);
                }
            } else expect(false, "%s".format(cell.flag));
        }

        writefln("\t%s air, %s pixel cells", airCellCount, M4_CELLS_PER_CHUNK-airCellCount);

        /// All cells are air -> switch to an air chunk
        if(airCellCount==M4_CELLS_PER_CHUNK) {
            srcRoot().flag = M4Root.Flag.AIR;
            return [M4Root.Flag.AIR,
                    0,
                    0,
                    0];
        }

        return newVoxels[0..dest];
    }
}