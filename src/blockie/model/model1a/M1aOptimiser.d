module blockie.model.model1a.M1aOptimiser;

import blockie.model;
import blockie.model.model1a;

final class M1aOptimiser : Optimiser {
private:
    M1aChunkEditView view;
    ubyte[] originalVoxels;
    uint voxelsLength;
public:
    this(M1aChunkEditView view) {
        this.view = view;
    }
    override ubyte[] optimise(ubyte[] voxels, uint voxelsLength) {
        this.originalVoxels = voxels;
        this.voxelsLength   = voxelsLength;

        if(view.isAir()) {
            return cast(ubyte[])[M1aFlag.AIR, 0] ~ view.root().flags.distance.toBytes();
        }

        //auto optVoxels = convertToReadOptimised();
        auto optVoxels = originalVoxels;

        writefln("\toptimised %s --> %s (%.2f%%)",
            voxelsLength, optVoxels.length, optVoxels.length*100.0 / voxelsLength);

        todo();

        return originalVoxels;
    }
private:
    M1aEditRoot* oldRoot() { return cast(M1aEditRoot*)originalVoxels.ptr; }

    // Tuple!(M1aOptLeaf[],uint[]) getUniqueLeaves() {
    //     M1aOptLeaf[] leaves;
    //     uint[] oldToNew;

    //     static struct Unique {
    //         M1aOptLeaf leaf;
    //         uint count;
    //         Stack!uint indexes;
    //         this(M1aOptLeaf* l) {
    //             leaf    = *l;
    //             count   = 1;
    //             indexes = new Stack!uint(4);
    //         }
    //     }
    //     Unique[ulong] map;

    //     void _eachBranch(M1aEditBranch* branch) {

    //     }
    //     void _eachCell(ref M1aEditCell cell) {
    //         if(!cell.isSolid()) {
    //             foreach(oct; 0..8) {

    //                 auto b = cell.getBranch(originalVoxels.ptr, oct);

    //             }
    //         }
    //     }

    //     foreach(ref cell; oldRoot().cells) {
    //         _eachCell(cell);
    //     }

    //     return tuple(leaves,oldToNew);
    // }
    ubyte[] convertToReadOptimised() {

        ubyte[] voxels;



        return voxels;
    }
}