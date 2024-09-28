# Model 2

Encodes voxel structure. 1 bit per voxel.

x |0000|1|1|1|1|1|1|
y |0000|1|1|1|1|1|1|
z |0000|1|1|1|1|1|1|
  |    | | | | | └─┴─ 8 voxels (level 0)
  |    | | | | └─┴─── 64 leaves (level 1)   
  |    | | | └─┴───── 512 branches (level 2)
  |    | | └─┴─────── 4096 branches (level 3) 
  |    | └─┴───────── 32768 branches (level 4)
  |    └─┴─────────── 262144 branches (level 5)
  |    |
  └────┴───────────── 4096 cells

[chunk (1,073,741,824) voxels]
  |
  ↓
 [cells (2,097,152 voxels)]
   |
   ↓
  [branches 5 (262,144 voxels)]
    |
    ↓
   [branches 4 (32768 voxels)]
     |
     ↓
    [branches 3 (4096 voxels)]
      |
      ↓
     [branches 2 (512 voxels)]
       |
       ↓
      [leaves (64 voxels)]
        |
        ↓
       [voxels (8 voxels)]  
