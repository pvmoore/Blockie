module blockie.version_;

const string version_ = "0.0.33";

/**===============================================================

    Todo:
   ===============================================================

    - Add voxel de-optimiser code
    - Create a single solid chunk test scene
    - Create a single solid cell test scene

    Checkerboard ray marching:
    ===============================================================
    Cast one ray every 4 square pixels. The distance is then used for the subsequent three pixels
    in the square as a start point. This should mean three of the four pixels are faster to compute.
    The downside is that there is a risk of a very small artifact but this seems unlikely. A small
    step-back factor can be used if this seems to be a problem. If this works, a one in nine square
    can be tried for more performance.

    Notes:
    ===============================================================
    - It might be necessary to reduce the size of a chunk if editing a 10^^3 chunk in real-time
      is too slow.


0.0.33 - Refactor some Model code. Move some old model code into 'unused_src' directory.

0.0.32 - Use Imgui for UI

0.0.31 - Remove OpenGL renderer

0.0.30 - Add Model3b which is described in blockie.generate.model.model3b.md

       - Add 'useful_functions.comp' code to the project as these functions would not have been
         visible to anyone other than myself
*/
