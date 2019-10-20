module blockie.version_;

const string version_ = "0.0.22";

/**===============================================================
    History

Upcoming ...
    - Add voxel de-optimiser code

0.0.22 - Use monospace font for on screen display. Reformat OSD.
         Distance field optimisation.

0.0.21 - Remove some redundant code in distance calculation.

0.0.20 - Improvements to Model 4

0.0.19 - Implement new Model 4 idea

0.0.18 - Use 6 bytes for chunk distance fields allowing a distance of 255 instead of 15.

0.0.17 - Test speed of larger cell distance fields for Model 3. Not much improvement for
         higher memory usage.

0.0.16 - Use ChunkEditViews when generating distances.

0.0.15 - Tidy up generation.

0.0.14 - Refactor Model1 generation to remove technical debt.

0.0.13 - Add Model 4 which does not use an octree but instead uses arrays of pixels
         for populated cells. On Hold.

0.0.12 - Add Model 3 which is like Model 2 but using a 5 bit root.

0.0.11 - Tidy up. Remove unused files.
         Refactor domain to a more modular system.
         Add Model2 which only stores boolean information for a voxel ie. whether it
         is air or not-air. This is more compact than model1 and also slightly faster.
         Obviously another mechanism for material is required for this model unless
         you want all voxels to be the same material.
         Rename a lot of files.

0.0.10 - Lots of changes. Great improvment to compute speed
         and reduction in voxel data size.

=================================================================*/

