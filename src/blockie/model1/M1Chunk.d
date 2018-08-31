module blockie.model1.M1Chunk;

import blockie.all;
import blockie.model.Chunk;

final class M1Chunk : Chunk {
public:
    /// Creates an air chunk
    this(chunkcoords coords) {
        super(coords);

        /// Set to air
        voxels.length = OctreeFlags.sizeof;
        this.root().flags.flag = OctreeFlag.AIR;
    }

    override bool isAir() {
        return root().flags.flag==OctreeFlag.AIR;
    }
    override bool isAirCell(uint cellIndex) {
        assert(cellIndex<4096);
        return optimisedRoot().isAir(cellIndex);
    }
    override void setDistance(ubyte x, ubyte y, ubyte z) {
        auto r = root();
        r.flags.distX = x;
        r.flags.distY = y;
        r.flags.distZ = z;
    }
    override void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z) {
        assert(cell<4096);
        auto r = optimisedRoot();
        assert(isAirCell(cell), "%s %s".format(pos, cell));
        r.setDField(cell, x,y,z);
    }

    OctreeRoot* root()             { return cast(OctreeRoot*)voxels.ptr; }
    OptimisedRoot* optimisedRoot() { return cast(OptimisedRoot*)voxels.ptr; }
}

auto beginEdit(M1Chunk c) {
    return new M1ChunkEditView(c);
}
void endEdit(M1Chunk c, M1ChunkEditView view) {
    c.voxels = view.getOptimisedVoxels();
    c.version_++;
}
