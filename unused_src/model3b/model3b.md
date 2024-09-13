# Model 3B

## Idea

Reduce the memory usage by using implied offsets for each level of the octree rather than specifying an offset for the next level down. This is for the optimised view. The edit view remains unchanged.

eg. Model 3 uses this for each optimised branch:
```
struct Branch {
    ubyte bits
    ubyte[3] offset;  // to 1..8 branches one level down
}
```

Model 3b only needs to specify the bits and an extra array with the popcounts of the bits array for each level
eg for level X.
```
ubyte[] bits;       // all the bits for level X
uint[] popcounts;   // the popcounts for level X
```

Functionally the popcounts are not required since the position of the bits on level X+1 can be determined by counting the popcounts of the bits on level X manually  but this is inefficient. So popcounts are for performance only.

## Implementation

- M3bOptimiser          Called from M3bOptimiser via a version directive.
- M3bTest               Called from M3bOptimiser for testing. Usually commented out
- pass1_marchM3b.comp
- marchM3b.inc

## Results

Slightly disappointing. The rendering speed is quite a bit slower than for Model 3. I think this is because we need to do two lookups per level instead of one. Also, we don't optimise duplicate nodes as efficiently. The memory usage is sometimes better and sometimes worse because of this.

