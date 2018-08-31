module blockie.model.DistanceFields;

import blockie.all;
import std.algorithm.searching : minElement, maxElement;
import std.algorithm.iteration : fold;

///
/// Generate air chunks at a radius of 6 around the perimeter
/// of the given chunks and set the distance fields.
///
void calculateChunkDistances(Chunk[] chunks, ChunkStorage storage) {
    if(chunks.length==0) return;

    chunkcoords chunkMin = chunks.map!(it=>it.pos)
                                 .fold!((a,b)=>a.min(b))(chunkcoords(int.max));
    chunkcoords chunkMax = chunks.map!(it=>it.pos)
                                 .fold!((a,b)=>a.max(b))(chunkcoords(int.min));
    const int RADIUS = 10;
    chunkMin -= RADIUS;
    chunkMax += RADIUS;
    int MAX_DISTANCE = (chunkMax.max() - chunkMin.min())+1;
    if(MAX_DISTANCE>255) MAX_DISTANCE = 255;

    writefln("calculateChunkDistances: min=%s max=%s", chunkMin, chunkMax);
    //writefln("views = %s", chunks.sort!((a,b)=>a.pos.y<b.pos.y).map!(it=>"%s".format(it.pos)).join(" "));

    Chunk[chunkcoords] map;
    uint numAirChunks;
    int maxDistanceX, maxDistanceY, maxDistanceZ;
    Chunk fakeChunk = storage.model.makeChunk(chunkcoords(int.min));


    Chunk getChunk(chunkcoords p) {
        auto ptr = p in map;
        if(ptr) return *ptr;

        if(p.anyLT(chunkMin) || p.anyGT(chunkMax)) return fakeChunk;
        Chunk c = storage.blockingGet(p);
        map[p] = c;
        return c;
    }
    bool isAirX(int x, chunkcoords min, chunkcoords max) {
        for(auto z=min.z; z<=max.z; z++)
            for(auto y=min.y; y<=max.y; y++) {
                if(!getChunk(chunkcoords(x,y,z)).isAir) return false;
            }
        return true;
    }
    bool isAirY(int y, chunkcoords min, chunkcoords max) {
        for(auto z=min.z; z<=max.z; z++)
            for(auto x=min.x; x<=max.x; x++) {
                if(!getChunk(chunkcoords(x,y,z)).isAir) return false;
            }
        return true;
    }
    bool isAirZ(int z, chunkcoords min, chunkcoords max) {
        for(auto y=min.y; y<=max.y; y++)
            for(auto x=min.x; x<=max.x; x++) {
                if(!getChunk(chunkcoords(x,y,z)).isAir) return false;
            }
        return true;
    }
    void setDistance(Chunk chunk) {
        bool gox = true, goy = true, goz = true;
        chunkcoords min = chunk.pos;
        chunkcoords max = chunk.pos;
        ubyte x,y,z;

        while(gox || goy || goz) {
            if(gox) {
                /// expand X
                if(isAirX(min.x-1, min, max) &&
                isAirX(max.x+1, min, max))
                {
                    x++;
                    min.x--; max.x++;
                    if(x==MAX_DISTANCE) gox = false;
                }
                else gox = false;
            }
            if(goy) {
                /// expand Y
                if(isAirY(min.y-1, min, max) &&
                isAirY(max.y+1, min, max))
                {
                    y++;
                    min.y--; max.y++;
                    if(y==MAX_DISTANCE) goy = false;
                }
                else goy = false;
            }
            if(goz) {
                /// expand Z
                if(isAirZ(min.z-1, min, max) &&
                isAirZ(max.z+1, min, max))
                {
                    z++;
                    min.z--; max.z++;
                    if(z==MAX_DISTANCE) goz = false;
                }
                else goz = false;
            }
        }
        chunk.setDistance(x,y,z);
        if(x>maxDistanceX) maxDistanceX=x;
        if(y>maxDistanceY) maxDistanceY=y;
        if(z>maxDistanceZ) maxDistanceZ=z;
    }


    /// store existing non-air chunks
    foreach(c; chunks) {
        map[c.pos] = c;
    }

    /// Traverse all chunks including margin.
    for(auto z=chunkMin.z; z<=chunkMax.z; z++)
    for(auto y=chunkMin.y; y<=chunkMax.y; y++)
    for(auto x=chunkMin.x; x<=chunkMax.x; x++) {
        auto pos   = chunkcoords(x,y,z);
        auto chunk = getChunk(pos);
        if(chunk.isAir) {
            numAirChunks++;
            setDistance(chunk);
        }
    }

    writefln("MAX_DISTANCE = %s", MAX_DISTANCE);
    writefln("maxDistanceXYZ=%s,%s,%s", maxDistanceX, maxDistanceY, maxDistanceZ);
    writefln("Chunks in = %s", chunks.length);
    writefln("Chunk grid (%s chunks)", map.length);
    writefln("numAirChunks=%s", numAirChunks);
    //return map.values.filter!(it=>it.isAir).array;
}
//======================================================================================================
///
/// Calculate and set distance fields in the cells.
/// For root bits of 10 this will be 4096 cells per chunk.
///
/// We have 2 ubytes to store x,y,z distance (5 bits each + 1 bit spare)
///
void calculateCellDistances(Chunk[] chunks, Model model) {
    if(chunks.length==0) return;

    log("Calculating cell distances");

    const MAX_DISTANCE = 31;
    const chunkMin = chunks.map!(it=>it.pos)
                           .fold!((a,b)=>a.min(b))(chunkcoords(int.max));
    const chunkMax = chunks.map!(it=>it.pos)
                           .fold!((a,b)=>a.max(b))(chunkcoords(int.min));
    Chunk[chunkcoords] map;
    foreach(c; chunks) {
        map[c.pos] = c;
    }
    Chunk fakeChunk = model.makeChunk(chunkcoords(int.min));

    Chunk getChunk(chunkcoords p) {
        auto ptr = p in map;
        if(ptr) return *ptr;
        return fakeChunk;
    }
    uint getOctree(int3 p) {
        assert(p.allLT(16) && p.allGTE(0));
        return p.dot(int3(1, 16, 256));
        //return (p << int3(0, OCTREE_ROOT_BITS, OCTREE_ROOT_BITS*2)).hadd();
    }
    /// In global cellcoords
    bool isAirCell(int3 p) {
        auto chunkpos = p>>OCTREE_ROOT_BITS;
        Chunk chunk   = getChunk(chunkpos);
        if(chunk.isAir) return true;

        int3 rem = p-(chunkpos<<OCTREE_ROOT_BITS);
        uint oct = getOctree(rem);
        return chunk.isAirCell(oct);
    }
    bool isAirX(int x, int3 min, int3 max) {
        for(auto z=min.z; z<=max.z; z++)
        for(auto y=min.y; y<=max.y; y++) {
            if(!isAirCell(int3(x,y,z))) return false;
        }
        return true;
    }
    bool isAirY(int y, int3 min, int3 max) {
        for(auto z=min.z; z<=max.z; z++)
        for(auto x=min.x; x<=max.x; x++) {
            if(!isAirCell(int3(x,y,z))) return false;
        }
        return true;
    }
    bool isAirZ(int z, int3 min, int3 max) {
        for(auto y=min.y; y<=max.y; y++)
        for(auto x=min.x; x<=max.x; x++) {
            if(!isAirCell(int3(x,y,z))) return false;
        }
        return true;
    }
    void setDistance(Chunk chunk, int3 cell) {
        assert(cell.allLT(16));
        //writefln("setDistance(%s,%s)", chunk.pos, offset);
        bool gox = true, goy = true, goz = true;
        int3 min = (chunk.pos<<OCTREE_ROOT_BITS)+cell;
        int3 max = min;
        ubyte x,y,z;

        while(gox || goy || goz) {
            if(gox) {
                /// expand X
                if(isAirX(min.x-1, min, max) &&
                   isAirX(max.x+1, min, max))
                {
                    x++;
                    min.x--; max.x++;
                    if(x==MAX_DISTANCE) gox = false;
                }
                else gox = false;
            }
            if(goy) {
                /// expand Y
                if(isAirY(min.y-1, min, max) &&
                   isAirY(max.y+1, min, max))
                {
                    y++;
                    min.y--; max.y++;
                    if(y==MAX_DISTANCE) goy = false;
                }
                else goy = false;
            }
            if(goz) {
                /// expand Z
                if(isAirZ(min.z-1, min, max) &&
                   isAirZ(max.z+1, min, max))
                {
                    z++;
                    min.z--; max.z++;
                    if(z==MAX_DISTANCE) goz = false;
                }
                else goz = false;
            }
        }

        uint oct = getOctree(cell);
        chunk.setCellDistance(oct, x,y,z);
    }

    const SIZE = 1<<OCTREE_ROOT_BITS;   /// 16
    assert(SIZE==16);

    /// Each chunk has 16^3 cells (4096)
    foreach(chunk; chunks) {
        if(!chunk.isAir) {
            for(int z=0; z<SIZE; z++)
            for(int y=0; y<SIZE; y++)
            for(int x=0; x<SIZE; x++) {
                auto p = int3(x,y,z);

                if(chunk.isAirCell(getOctree(p))) {
                    setDistance(chunk, p);
                }
            }
        }
    }
    log("Calculating cell distances finished"); flushLog();
}