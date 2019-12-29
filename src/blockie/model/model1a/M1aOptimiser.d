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

        if(view.isAir) {
            return cast(ubyte[])[M1aFlag.AIR, 0] ~ view.root().flags.distance.toBytes();
        }

        todo();

        return originalVoxels;
    }
}