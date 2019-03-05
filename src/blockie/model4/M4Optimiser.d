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
            return cast(ubyte[])[M4Root.Flag.AIR, 0] ~ view.root().distance.toBytes();
        }

        writefln("Optimiser: Processing %s", view);

        auto optVoxels = rewriteVoxels(voxels[0..voxelsLength]);

        writefln("\tOptimised chunk %s %s --> %s (%.2f%%)", view.getChunk.pos,
            voxelsLength, optVoxels.length, optVoxels.length*100.0 / voxelsLength);

        return optVoxels;
    }
private:
    /// 1) If flag==MIXED_PIXELS and cell is solid -> Set flag = SOLID_PIXELS and remove pixels
    /// 2) If flag==MIXED_PIXELS and cell is air -> Set flag = AIR and remove pixels
    /// 3) Remove any gaps
    ubyte[] rewriteVoxels(ubyte[] srcVoxels) {

        auto newVoxels = new ubyte[voxelsLength];
        uint dest      = M4_ROOT_SIZE;

        M4Root* srcRoot()  { return cast(M4Root*)srcVoxels.ptr; }
        M4Root* destRoot() { return cast(M4Root*)newVoxels.ptr; }

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

        auto pixelCells = M4_CELLS_PER_CHUNK-airCellCount;

        auto distanceBytes = airCellCount*4;
        auto pixelBytes = pixelCells*M4_PIXELS_SIZE;
        auto totalBytes = distanceBytes + pixelBytes;

        totalDistanceBytes += distanceBytes;
        totalPixelBytes    += pixelBytes;

        writefln("\t#air cells   = %000,d", airCellCount);
        writefln("\t#pixel cells = %000,d",  pixelCells);
        writefln("\tair cells size    = %000,d", (airCellCount*4));
        writefln("\tpixels cells size = %000,d", (pixelCells*M4_PIXELS_SIZE));
        writefln("\tTotal bytes       = %000,d", totalBytes);

        writefln("totalDistance : %000,d", totalDistanceBytes);
        writefln("totalPixel    : %000,d", totalPixelBytes);

        /// All cells are air -> switch to an air chunk
        if(airCellCount==M4_CELLS_PER_CHUNK) {
            srcRoot().flag = M4Root.Flag.AIR;
            return cast(ubyte[])[M4Root.Flag.AIR, 0, 0,0,0,0,0,0];
        }

        return newVoxels[0..dest];
    }
    static ulong totalPixelBytes = 0;
    static ulong totalDistanceBytes = 0;
}