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

# Ideas
- The voxel ubyte value only specifies the general type. The actual voxel that is shown is taken from a fractal algorithm so that a variety of rocks can be represented by the same rock voxel for example.

- Hash root cells if they are taking up too much memory

##### Vulkan
    It might not be too much work (relatively) to convert to Vulkan.

##### Preprocess scene
    Run march pass on 1/4 or 1/9 of the pixels and store the distances. eg
    x . or . . .
    . .    . x .
           . . .
    If nothing is hit then don't run full march pass on that block. If a distance is found then start at that distance
    when running full pass on the rest of that block.
    
##### Store static results
    If the camera does not move between frames than any static results can be re-used
    
##### Accuracy issues
    Use doubles on any area that seems to be affected poorly by accuracy of floats. It doubles are used minimally
    then speed should not be affected negatively (much). 
    
    
 ===================================================================
##### Old Todo: These might no longer be relevant
 
 -   gl_compute_renderer only needs one texture for materials which
     needs to be atlased. Need to do a modulus on the current hitPos.xz+y
     uv coords to get the uv coord in the atlas.
 
 -   Investigate shadow mapping
 
 -   Add shadow rays
 
 -   Ambient occlusion
     -   Nothing seems to work very well using hit pos data. Maybe try bouncing low-res rays
         off the hit point.
 -   Try low resolution marching as the first pass. eg. 8x8 screen pixels per ray. Follow
     this up with 1 ray per pixel for areas that have hit something. This might not work
     well if the initial ray misses some smaller voxel. Need to try it to know for sure.
   