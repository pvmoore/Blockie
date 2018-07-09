module blockie.generate.distance_fields;
/**
 *
 */
import blockie.all;
import std.algorithm.searching : minElement, maxElement;
import std.algorithm.iteration : fold;

/**
 *  Generate air chunks at a radius of 8 around the perimeter
 *  of the given chunks and set the distance fields.
 */
Chunk[] generateAirChunks(Chunk[] chunks) {
    ivec3 chunkMin = chunks.map!(it=>it.pos)
                           .fold!((a,b)=>a.min(b))(ivec3(int.max));
    ivec3 chunkMax = chunks.map!(it=>it.pos)
                           .fold!((a,b)=>a.max(b))(ivec3(int.min));
    const int RADIUS = 6;
    chunkMin -= RADIUS;
    chunkMax += RADIUS;
    int MAX_DISTANCE = (chunkMax.max() - chunkMin.min())+1;
    if(MAX_DISTANCE>255) MAX_DISTANCE = 255;

    //writefln("generateAirChunks: min=%s max=%s", chunkMin, chunkMax);
    //writefln("views = %s", chunks.sort!((a,b)=>a.pos.y<b.pos.y).map!(it=>"%s".format(it.pos)).join(" "));

    Chunk[ivec3] map;
    uint numAirChunks;
    int maxDistanceX, maxDistanceY, maxDistanceZ;
    Chunk fakeChunk = Chunk.airChunk(ivec3(int.min));

    pragma(inline,true) {
        Chunk getChunk(ivec3 p) {
            auto ptr = p in map;
            if(ptr) return *ptr;
            if(p.anyLT(chunkMin) || p.anyGT(chunkMax)) return fakeChunk;
            Chunk c = Chunk.airChunk(p);
            map[p] = c;
            return c;
        }
        bool isAirX(int x, ivec3 min, ivec3 max) {
            for(auto z=min.z; z<=max.z; z++)
            for(auto y=min.y; y<=max.y; y++) {
                if(!getChunk(ivec3(x,y,z)).isAir) return false;
            }
            return true;
        }
        bool isAirY(int y, ivec3 min, ivec3 max) {
            for(auto z=min.z; z<=max.z; z++)
            for(auto x=min.x; x<=max.x; x++) {
                if(!getChunk(ivec3(x,y,z)).isAir) return false;
            }
            return true;
        }
        bool isAirZ(int z, ivec3 min, ivec3 max) {
            for(auto y=min.y; y<=max.y; y++)
            for(auto x=min.x; x<=max.x; x++) {
                if(!getChunk(ivec3(x,y,z)).isAir) return false;
            }
            return true;
        }
        void setDistance(Chunk chunk) {
            bool gox = true, goy = true, goz = true;
            ivec3 min = chunk.pos;
            ivec3 max = chunk.pos;
            ubyte x,y,z;

            while(gox || goy || goz) {
                if(gox) {
                    // expand X
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
                    // expand Y
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
                    // expand Z
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
            chunk.root.flags.distX = x;
            chunk.root.flags.distY = y;
            chunk.root.flags.distZ = z;
            if(x>maxDistanceX) maxDistanceX=x;
            if(y>maxDistanceY) maxDistanceY=y;
            if(z>maxDistanceZ) maxDistanceZ=z;
        }
    }

    // store existing non-air chunks
    foreach(c; chunks) {
        map[c.pos] = c;
    }

    // Traverse all chunks including margin.
    for(auto z=chunkMin.z; z<=chunkMax.z; z++)
    for(auto y=chunkMin.y; y<=chunkMax.y; y++)
    for(auto x=chunkMin.x; x<=chunkMax.x; x++) {
        auto pos   = ivec3(x,y,z);
        auto chunk = getChunk(pos);
        if(chunk.isAir) {
            numAirChunks++;
            setDistance(chunk);
        }
    }
//    writefln("MAX_DISTANCE = %s", MAX_DISTANCE);
//    writefln("maxDistanceXYZ=%s,%s,%s", maxDistanceX, maxDistanceY, maxDistanceZ);
//    writefln("Chunks in = %s", chunks.length);
//    writefln("Chunk grid (%s chunks)", map.length);
//    writefln("numAirChunks=%s", numAirChunks);
    return map.values.filter!(it=>it.isAir).array;
}
/**
 *  Calculate and set distance fields in the root branches.
 *  For root bits of 3 this will be 512 nibbles per chunk.
 *
 *  We have 2 ubytes to store x,y,z distance (5 bits each + 1 bit spare)
 */
void calculateAirNibbles(Chunk[] chunks) {
    const MAX_DISTANCE = 31;
    const chunkMin = chunks.map!(it=>it.pos)
                           .fold!((a,b)=>a.min(b))(ivec3(int.max));
    const chunkMax = chunks.map!(it=>it.pos)
                           .fold!((a,b)=>a.max(b))(ivec3(int.min));
    Chunk[ivec3] map;
    foreach(c; chunks) {
        map[c.pos] = c;
    }
    Chunk fakeChunk = Chunk.airChunk(ivec3(int.min));

    pragma(inline,true) {
        Chunk getChunk(ivec3 p) {
            auto ptr = p in map;
            if(ptr) return *ptr;
            return fakeChunk;
        }
        bool isAirNibble(ivec3 p) {
            auto chunkpos = p >> OCTREE_ROOT_BITS;
            Chunk chunk = getChunk(chunkpos);
            if(chunk.isAir) return true;

            ivec3 rem = p-(chunkpos<<OCTREE_ROOT_BITS);
            auto root = chunk.optimisedRoot;
            uint oct  = root.getOctree(rem);
            return root.isAir(oct);
        }
        bool isAirX(int x, ivec3 min, ivec3 max) {
            for(auto z=min.z; z<=max.z; z++)
            for(auto y=min.y; y<=max.y; y++) {
                if(!isAirNibble(ivec3(x,y,z))) return false;
            }
            return true;
        }
        bool isAirY(int y, ivec3 min, ivec3 max) {
            for(auto z=min.z; z<=max.z; z++)
            for(auto x=min.x; x<=max.x; x++) {
                if(!isAirNibble(ivec3(x,y,z))) return false;
            }
            return true;
        }
        bool isAirZ(int z, ivec3 min, ivec3 max) {
            for(auto y=min.y; y<=max.y; y++)
            for(auto x=min.x; x<=max.x; x++) {
                if(!isAirNibble(ivec3(x,y,z))) return false;
            }
            return true;
        }
        void setDistance(Chunk chunk, ivec3 offset) {
            //writefln("setDistance(%s,%s)", chunk.pos, offset);
            bool gox = true, goy = true, goz = true;
            ivec3 min = (chunk.pos<<OCTREE_ROOT_BITS)+offset;
            ivec3 max = min;
            ubyte x,y,z;

            while(gox || goy || goz) {
                if(gox) {
                    // expand X
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
                    // expand Y
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
                    // expand Z
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
            auto root = chunk.optimisedRoot;
            uint oct  = root.getOctree(offset);
            root.setDField(oct, x,y,z);
        }
    }

    const SIZE = 1<<OCTREE_ROOT_BITS;   // 8

    foreach(chunk; chunks) {
        if(!chunk.isAir) {
            for(int z=0; z<SIZE; z++)
            for(int y=0; y<SIZE; y++)
            for(int x=0; x<SIZE; x++) {
                setDistance(chunk, ivec3(x,y,z));
            }
        }
    }
}



