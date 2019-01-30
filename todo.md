# Blockie Todo
- SSAO
- Load minecraft maps/heightmaps
- Test fp16 speed
- Shadow ray could be done in lower resolution to save time (or use lower resolution octree).
- Multiple render passes:  One could be for anti-aliasing.
- Do shadows in a later pass using depth data.
- Store depth data of each separate voxel entity until camera moves.
- TestScene4 - Make snow and rock more random.
- Fog (this will also help with performance)
- Fractal textures using Perlin noise.
- Editor – add/remove voxels.
- setVoxel(x,y,z, value, size) -> set large voxel blocks in a single call.

## Ideas
- The voxel ubyte value only specifies the general type. The actual voxel that is shown is taken from a fractal algorithm so that a variety of rocks can be represented by the same rock voxel for example.
- It might not be too much work (relatively) to convert to Vulkan.
