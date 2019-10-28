module blockie.model.Optimiser;

interface Optimiser {
    ubyte[] optimise(ubyte[] voxels, uint voxelsLength);
}