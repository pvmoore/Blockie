# Statistics

Notes:
Model 3 has superior speed compared to Model 2 with only
a small cost in extra memory usage so should be preferred.

## Models

### Model 1

Stores one byte per voxel (8 bits are used to store the voxel type)
The top 4 bits of each chunk are stored as cells (4096 cells per chunk). 
The bottom 6 bits are octrees if the cell is not air.

Note that for some scenes the memory usage of this model is better than or similar to Model2 even though it
stores 8 bits of voxel info rather than 1. This is because it takes advantage of the fact that a lot of
octree nodes are duplicated and the optimised storage of this model allows to point to other octrees leading
to a reduction in memory usage. This only works well for scenes that have a lot of repetition which is why it seems
good some of the test scenes I am currently using which are simple. Other models do not have the ability to point to other
octrees so this duplication is not removed.

### Model2

Stores 1 bit per voxel so the voxel is either solid or air. 
The top 4 bits of each chunk are stored as cells (4096 cells per chunk). 
The bottom 6 bits are octrees if the cell is not air

### Model3

The same as Model2 but uses 5 bits for the root rather than 4.
The top 5 bits of each chunk are stored as cells (32768 cells per chunk). 
The bottom 5 bits are octrees if the cell is not air


## GPU Memory Usage (MB)

Scene |   M1  |  M2  |   M3  |  
------|-------|------|-------|
  1   |    2  |   0  |    0  |
  2   |    5  |   0  |    2  |
  3   |    8  |   1  |    5  |
  4   |  242  | 256  |  286  |
  4b  |   54  |  48  |   56  |
  4c  |   79  |  62  |   68  |
  5   |    2  |   1  |    1  |
  6   |   53  |  41  |   42  |
  7   |   32  |  30  |   31  |
  8   |    1  |   1  |    1  |

## Frames Per Second (1920x1080)

### Radeon 6600 Vulkan (Release build)

Scene |  (M1) |  M2  |  (M3) |
------|-------|------|-------|
  1   |  1200 | 1400 |  1500 |
  2   |  1600 | 1900 |  2000 |
  3   |   500 |  650 |   770 |
  4   |   380 |  480 |   510 |
  4b  |   385 |  500 |   525 |
  4c  |   355 |  470 |   505 |
  5   |  1450 | 1600 |  1750 |
  6   |   830 |  960 |  1050 | Bunny
  7   |   465 |  590 |   635 | Height map landscape
  8   |   850 | 1050 |  1080 |

### Radeon 7700XT Vulkan (Release build)

Scene |  (M1) |  M2  |  (M3) |
------|-------|------|-------|
  1   |       |      |  2000 |
  2   |       |      |  2000 |
  3   |       |      |  1200 |
  4   |       |      |  1000 |
  4b  |       |      |  1100 |
  4c  |       |      |  1100 |
  5   |       |      |  2000 |
  6   |       |      |  1750 | Bunny
  7   |       |      |  1100 | Height map landscape
  8   |       |      |  1600 |
