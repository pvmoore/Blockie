module blockie.model.Optimiser;

import blockie.model;

interface Optimiser {
    ubyte[] optimise(ubyte[] voxels, uint voxelsLength);
}