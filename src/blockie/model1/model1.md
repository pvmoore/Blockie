# Model 1

## Chunks, Cells and Voxels

Each chunk is 2<sup>10</sup> * 2<sup>10</sup> * 2<sup>10</sup> (1024 * 1024 * 1024) voxels. 
This is 1,073,741,824 voxels per chunk.

Each chunk is made up of 2<sup>4</sup> (16 * 16 * 16) (4096) Cells.

Each Cell contains a maximum of 2<sup>6</sup> (64 * 64 * 64) (262,144) voxels.

### Bit layout

A voxel location within a Chunk is defined as (10 bit X, 10 bit Y, 10 bit Z). The highest 4 bits gives
the Cell. The lower 6 bits gives the voxel.

X:
11_1100_0000  cell
     10_0000  branch
      1_0000  branch
        1000  branch
         100  branch
          10  leaf
           1  voxel index

Y:
11_1100_0000  cell
     10_0000  branch
      1_0000  branch
        1000  branch
         100  branch
          10  leaf
           1  voxel index

Z:
11_1100_0000  cell
     10_0000  branch
      1_0000  branch
        1000  branch
         100  branch
          10  leaf
           1  voxel index    

## Edit View

This format represents the voxels in a way that is efficient but easier to modify than the optimised view.

- [0] ubyte flag (1=AIR, 2=MIXED)
- [1] ubyte unused
- [2] 6 bytes - Chunk distance field representing the distance to the next populated Chunk (2 bytes per axis)
- [8] 4096 bits             - 1 bit per cell (0 = the cell is solid, 1 = the cell is mixed)
- [520] 4096 **OctreeIndex**es The first layer of octree information (or the solid voxel if bit == 0)
- [12808] 4096 **Distance3**s The cell distance field

### OctreeIndex

This is either an index to an OctreeBranch/OctreeLeaf or the first byte indicates the voxel if it is solid

```
ubyte[3] v;
```

### OctreeBranch

8 bits followed by 8 OctreeIndexes. The bits indicate whether or not the index points to another branch/leaf.
If the bit is 0 then the index contains a single voxel at byte 0 which is the solid voxel. Otherwise the index points
to another OctreeBranch or Octree Leaf of we are at the bottom level.

```
ubyte bits;
OctreeIndex[8] indexes;
```

### OctreeLeaf

An array of 8 voxel values

```
ubyte[8] voxels;
```

## Optimised View   

This view is optimised for memory and shader traversal. 

- [0] ubyte flag (1=AIR, 2=MIXED)
- [1] ubyte unused
- [2] 6 bytes - Chunk distance field representing the distance to the next populated Chunk (2 bytes per axis)
- [8] 

```
┌─┬─┬
├─┼─┼
├─┼─┼



┌────┬────┬─ 
│Cell│    │  
├────┼────┼─ 
│    │    │
├────┼────┼─ 


┌──┬──┐
│  │  │
├──┼──┤
│  │  │
└──┴──┘

╔══╦══╗
║  ║  ║
╠══╬══╣
║  ║  ║
╚══╩══╝


▀ ▀ ▀ 
▀ ▀ ▀ 
▀ ▀ ▀ 
```

https://en.wikipedia.org/wiki/Box-drawing_characters
