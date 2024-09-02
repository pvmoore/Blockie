# Statistics

Notes:
Model 3 has superior speed compared to Model 2 with only
a small cost in extra memory usage so should be preferred.

## Models

### Model 1

Stores one byte per voxel

### Model3

Stores 1 bit per voxel so the voxel is either solid or air.


## GPU Memory Usage (MB)

Scene |  M1  |  M2  |  M3  |  M4  |  M5  |  M6  |  M7
------|------|------|------|------|------|------|------
  1   |   2  |   0  |   0  |   2  |      |      |
  2   |   5  |   0  |   2  |  14  |      |      |
  3   |   8  |   1  |   5  |  28  |      |      |
  4   | 242  | 247  | 286  | 425  |      |      |
  4b  |  54  |  46  |  56  |  81  |      |      |
  4c  |  79  |  59  |  68  |  87  |      |      |
  5   |   2  |   1  |   1  |   1  |      |      |
  6   |  53  |  41  |  42  |  36  |      |      |
  7   |  32  |  28  |  31  | 243  |      |      |
  8   |   1  |   0  |   1  |   1  |      |      |

## Frames Per Second (1920x1080)

### Radeon 6600 Vulkan (Release build)

Scene |  (M1) |  M2  |  (M3) |
------|-------|------|-------|
  1   |  1200 |      |  1500 |
  2   |  1600 |      |  2000 |
  3   |   500 |      |   770 |
  4   |   380 |      |   510 |
  4b  |   385 |      |   525 |
  4c  |   355 |      |   505 |
  5   |  1450 |      |  1750 |
  6   |   830 |      |  1050 | Bunny
  7   |   465 |      |   635 | Height map landscape
  8   |   850 |      |  1080 |
