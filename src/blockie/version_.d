module blockie.version_;

const string version_ = "0.0.12";

/**===============================================================
    History

0.0.12 -

0.0.11 - Tidy up. Remove unused files.
         Refactor domain to a more modular system.
         Add Model2 which only stores boolean information for a voxel ie. whether it
         is air or not-air. This is more compact than model1 and also slightly faster.
         Obviously another mechanism for material is required for this model unless
         you want all voxels to be the same material.
         Rename a lot of files.
0.0.10 - Lots of changes. Great improvment to compute speed
         and reduction in voxel data size.

===================================================================
    Todo

-   gl_compute_renderer only needs one texture for materials which
    needs to be atlased. Need to do a modulus on the current hitPos.xz+y
    uv coords to get the uv coord in the atlas.

-   Investigate shadow mapping

-   Add shadow rays

-   Ambient occlusion
    -   Nothing seems to worl very well using hit pos data. Maybe try bouncing low-res rays
        off the hit point.
-   Try low resolution marching as the first pass. eg. 8x8 screen pixels per ray. Follow
    this up with 1 ray per pixel for areas that have hit something. This might not work
    well if the initial ray misses some smaller voxel. Need to try it to know for sure.

=================================================================*/

