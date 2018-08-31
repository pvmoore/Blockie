module blockie.model.WorldEditor;

import blockie.all;

interface WorldEditor {
    void destroy();
    void startTransaction();
    void commitTransaction();
    void setVoxel(worldcoords pos, ubyte value);
    void setVoxelBlock(worldcoords wpos, uint size, ubyte value);
    void rectangle(worldcoords min, worldcoords max, ubyte value);
    void rectangle(worldcoords min, worldcoords max, uint thickness, ubyte value);
    void sphere(worldcoords centre, uint minRadius, uint maxRadius, ubyte value);
    void cylinder(worldcoords start, worldcoords end, uint radius, ubyte value);
}