module blockie.domain.chunk.distance;

import blockie.all;
/+
/**
 *  Set distances to nearest non-air sub-chunk.
 *
 *  Each chunk has 8*8*8 (512) sub-chunks. A sub-chunk can store
 *  the distance in sub-chunks to the nearest sub-chunk where
 *  the content is not air.
 */
void calculateDistances(World world) {
    int x, y, z;
    int maxX = world.chunksX * 8;
    int maxY = world.chunksY * 8;
    int maxZ = world.chunksZ * 8;

    /// Returns the sub-chunk at (x+x2,y+y2,z+z2)
    pragma(inline,true)
    SparseBranch* getSubChunk(int x2, int y2, int z2) {
        int xx = x+x2;
        int yy = y+y2;
        int zz = z+z2;
        // xx,yy,zz are in sub-chunk coords.
        // convert to world voxel coords.
        return getSparseSubChunk(world, xx*SUB_CHUNK_SIZE,
                                        yy*SUB_CHUNK_SIZE,
                                        zz*SUB_CHUNK_SIZE);
    }

    ///
    pragma(inline,true)
    int getSubChunkDist(int xx, int yy, int zz) {
        SparseBranch* s = getSubChunk(xx,yy,zz);
        if(!s) return -1;
        if(s.isSolidAir) {
            return s.distance;
        }
        return 0;
    }

    ///
    pragma(inline,true)
    int calcDist() {
        int d = int.max;
        foreach(o; OFFSETS) {
            int scd = getSubChunkDist(o.x, o.y, o.z);
            if(scd>=0) {
                d = min(d, scd);
            }
            if(d==0) return 0;
        }
        return d;
    }

    ubyte lastMaxD = 0;
    ubyte maxD = 0;
    ubyte minD = 255;

    for(auto i=0; i<255; i++) {
        for(y=0; y<maxY; y++) {
            for(z=0; z<maxZ; z++) {
                for(x=0; x<maxX; x++) {
                    SparseBranch* sub = getSubChunk(0,0,0);
                    if(sub && sub.isSolidAir) {
                        ubyte d = cast(ubyte)(calcDist() + 1);
                        maxD = max(maxD, d);
                        minD = min(minD, d);
                        sub.distance = d;
                    }
                }
            }
        }
        if(maxD==lastMaxD) break;
        lastMaxD = maxD;
    }
    writefln("max distance = %s", maxD);
    writefln("min = %s", minD);

    int count1, count2, count3;
    for(y=0; y<maxY; y++)
    for(z=0; z<maxZ; z++)
    for(x=0; x<maxX; x++) {
        SparseBranch* sub = getSubChunk(0,0,0);
        if(sub && sub.isSolidAir) {
            ubyte d = sub.distance;
            if(d==1) count1++;
            if(d==2) count2++;
            if(d==3) count3++;
        }
    }
    writefln("1=%s 2=%s 3=%s", count1, count2, count3);
}

/*
y+1
  xyz
  uvw
  rst
y=0
  opq
  m n
  jkl
y-1
  ghi
  def
  abc
*/
struct Int3 { int x, y, z; }
__gshared const Int3[26] OFFSETS = [
    Int3(-1,-1,-1),
    Int3(0,-1,-1),
    Int3(1,-1,-1),

    Int3(-1,-1,0),
    Int3(0,-1,0),
    Int3(1,-1,0),

    Int3(-1,-1,1),
    Int3(0,-1,1),
    Int3(1,-1,1),

    Int3(-1,0,-1),
    Int3(0,0,-1),
    Int3(1,0,-1),

    Int3(-1,0,0),   // m
    Int3(1,0,0),    // n

    Int3(-1,0,1),
    Int3(0,0,1),
    Int3(1,0,1),

    Int3(-1,1,-1),
    Int3(0,1,-1),
    Int3(1,1,-1),

    Int3(-1,1,0),
    Int3(0,1,0),
    Int3(1,1,0),

    Int3(-1,1,1),
    Int3(0,1,1),
    Int3(1,1,1)
];
+/
