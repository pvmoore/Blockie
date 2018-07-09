module blockie.domain.chunk.convert;

import blockie.all;

/*
void convertToSparse(Chunk chunk) {
    //     Chunk  Array
    // LOD Size   Size
    //========================
    // 0  | 256 | 16MB          7
    // 1  | 128 | 2MB           6
    // 2  |  64 | 262KB         5
    // 3  |  32 | 32KB          4
    // 4  |  16 | 4K            3
    // 5  |   8 | 512 bytes     2
    // 6  |   4 | 64 bytes      1
    // 7  |   2 | 8 bytes       0
    //========================
    // total = 19,173,960 MB

    StopWatch watch;
    watch.start();

    auto bufs = iota(0,CHUNK_SIZE_SHR)
                .map!(it=>appender!(ubyte[]))
                .array;
    uint[CHUNK_SIZE_SHR-1] levelIndexes;

    pragma(inline, true)
    ubyte getSolid(uint X, uint Y, uint Z, uint size) {
        ubyte b = chunk.voxels[X +
                              (Z*CHUNK_SIZE) +
                              (Y*CHUNK_SIZE_SQUARED)];
        if(size==1) {
            return b;
        }
        for(auto y=Y; y<Y+size; y++)
        for(auto z=Z; z<Z+size; z++)
        for(auto x=X; x<X+size; x++)
        {
            ubyte b2 = chunk.voxels[x +
                                   (z*CHUNK_SIZE) +
                                   (y*CHUNK_SIZE_SQUARED)];
            if(b2!=b) {
                return V_SPECIAL;
            }
        }
        return b;
    }

    ubyte recurse(int level, uint x, uint y, uint z, uint chunkSize) {
        uint levelIndex;

        if(level>=0) {
            auto buf = bufs[level];
            ubyte b  = getSolid(x,y,z,chunkSize);

            if(b!=V_SPECIAL) {
                buf.put(b);
                if(chunkSize>1) {
                    buf.put(cast(ubyte)0);
                    buf.put(cast(ubyte)0);
                }
                return 0;
            }
            // recurse downwards
            levelIndex = levelIndexes[level]++;
            // write the levelIndex (little-endian)
            buf.put(cast(ubyte)levelIndex);
            buf.put(cast(ubyte)(levelIndex>>8));
            buf.put(cast(ubyte)(levelIndex>>16));
        }

        level++;
        auto lowerBuf = bufs[level];
        int h = chunkSize >> 1;
        ubyte bits;
        auto bitsOffset = lowerBuf.data.length;
        // if this is not the lowest level, write the
        // placeholder for the bitflags
        bool writeBitFlags = h>1;
        if(writeBitFlags) {
            lowerBuf.put(cast(ubyte)0);
        }
        bits |=  recurse(level, x,   y,   z,   h);
        bits |= (recurse(level, x+h, y,   z,   h) << 1);
        bits |= (recurse(level, x,   y,   z+h, h) << 2);
        bits |= (recurse(level, x+h, y,   z+h, h) << 3);
        bits |= (recurse(level, x,   y+h, z,   h) << 4);
        bits |= (recurse(level, x+h, y+h, z,   h) << 5);
        bits |= (recurse(level, x,   y+h, z+h, h) << 6);
        bits |= (recurse(level, x+h, y+h, z+h, h) << 7);
        // update the bitflags at the start of this node
        if(writeBitFlags) {
            lowerBuf.data[bitsOffset] = bits;
        }
        return 1;
    }

    if(false) {
        // start at level 0
        recurse(-1, 0,0,0, CHUNK_SIZE);
    } else {
        // start at level 3
        uint size = CHUNK_SIZE >> 3;
        for(auto y=0; y<CHUNK_SIZE; y+=size)
        for(auto z=0; z<CHUNK_SIZE; z+=size)
        for(auto x=0; x<CHUNK_SIZE; x+=size)
        {
            recurse(-1, x, y, z, size);
        }
    }

    chunk.sparseVoxels.length = 0;
    auto total = 0;
    foreach(i, b; bufs) {
        chunk.sparseVoxels ~= b.data;
        total += b.data.length;
        chunk.sparseLevelOffsets[i] = total;
    }

    //writefln("buf[0] %s", bufs[0].data);

    foreach(i, b; bufs) {
        //writefln("buf[%s] %s", i, b.data);
    }
    foreach(i, b; levelIndexes) {
        //writefln("index[%s] %s", i, b);
    }
    foreach(i, b; chunk.sparseLevelOffsets) {
        //writefln("offset[%s] %s", i, b);
    }
    writefln("sparseVoxels.length = %s", chunk.sparseVoxels.length);

    chunk.type = SPARSE;

    watch.stop();
    //writefln("Took %s millis converting to sparse", watch.peek().nsecs/1000000.0);
}
*/
