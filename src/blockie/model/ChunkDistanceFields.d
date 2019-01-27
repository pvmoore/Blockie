module blockie.model.ChunkDistanceFields;

import blockie.all;
import std.algorithm.searching : minElement, maxElement;
import std.algorithm.iteration : fold;

final class ChunkDistanceFields {
private:
    const int RADIUS = 20;
    ChunkStorage storage;
    Chunk[] chunks;
    StopWatch watch;
    Chunk[chunkcoords] map;
    Chunk fakeChunk;
    chunkcoords chunkMin, chunkMax, gridSize;
    int MAX;
    int3 maxDistance;
    int3[] distances;
public:
    this(ChunkStorage storage, Chunk[] chunks) {
        this.storage   = storage;
        this.chunks    = chunks;
        this.fakeChunk = storage.model.makeChunk(chunkcoords(int.min));

        this.chunkMin = chunks.map!(it=>it.pos)
                              .fold!((a,b)=>a.min(b))(chunkcoords(int.max));
        this.chunkMax = chunks.map!(it=>it.pos)
                              .fold!((a,b)=>a.max(b))(chunkcoords(int.min));

        chunkMin -= RADIUS;
        chunkMax += RADIUS;

        this.gridSize = chunkMax-chunkMin + 1;

        MAX = (chunkMax.max() - chunkMin.min())+1;
        if(MAX>255) MAX = 255;

        /// store existing non-air chunks
        foreach(c; chunks) {
            map[c.pos] = c;
        }

        this.distances = new int3[gridSize.hmul()];
    }
    auto generate() {
        if(chunks.length==0) return this;

        writefln("\nGenerating air chunks ..."); flushConsole();

        watch.start();

        calculateInitialDistances();
        processVolumes();

        watch.stop();

        writefln("\tmin          = %s", chunkMin);
        writefln("\tmax          = %s", chunkMax);
        writefln("\tsize         = %s", gridSize);
        writefln("\tMAX          = %s", MAX);
        writefln("\tmaxDistance  = %s", maxDistance);
        writefln("\tChunks in    = %s", chunks.length);
        writefln("\tChunk grid   = %s chunks", map.length);

        writefln("\tTook (%.2f seconds)", watch.peek().total!"nsecs"*1e-09);
        return this;
    }
private:
    Chunk getChunk(chunkcoords p) {
        auto ptr = p in map;
        if(ptr) return *ptr;

        if(p.anyLT(chunkMin) || p.anyGT(chunkMax)) return fakeChunk;

        Chunk c = storage.blockingGet(p);
        map[p] = c;
        return c;
    }
    bool isAir(int3 pos) {
        return getChunk(pos).isAir;
    }
    void calculateInitialDistances() {

        int3 maxDistance = int3(0,0,0);
        int numAirChunks;

        int3 process(int3 chunkPos, int index, int xstart, int ystart, int zstart) {
            int x,y,z;
            /// x
            for(int i=xstart; i<=MAX; i++) {
                if(isAir(chunkPos+int3(i,0,0)) && isAir(chunkPos+int3(-i,0,0))) {
                    x = i;
                } else break;
            }
            /// y
            for(int i=ystart; i<=MAX; i++) {
                if(isAir(chunkPos+int3(0,i,0)) && isAir(chunkPos+int3(0,-i,0))) {
                    y = i;
                } else break;
            }
            /// z
            for(int i=zstart; i<=MAX; i++) {
                if(isAir(chunkPos+int3(0,0,i)) && isAir(chunkPos+int3(0,0,-i))) {
                    z = i;
                } else break;
            }

            int3 d = int3(x,y,z);

            distances[index] = d;

            maxDistance = maxDistance.max(d);

            return d;
        }

        int index = 0;

        for(auto z=chunkMin.z; z<=chunkMax.z; z++) {
            for(auto y=chunkMin.y; y<=chunkMax.y; y++) {

                int3 dist;
                int xstart = 1;

                for(auto x=chunkMin.x; x<=chunkMax.x; x++) {
                    auto pos   = int3(x,y,z);
                    auto chunk = getChunk(pos);
                    if(chunk.isAir) {
                        numAirChunks++;

                        dist   = process(pos, index, xstart, 1, 1);
                        xstart = max(1, dist.x-1);
                    } else {
                        xstart = 1;
                    }
                    index++;
                }
            }
        }

        writefln("\tInitial max  = %s", maxDistance);
        writefln("\tnumAirChunks = %s", numAirChunks);
    }
    void processVolumes() {

        int3 maxDistance = int3(0,0,0);
        const int X      = 1;
        const int Y      = gridSize.x;
        const int Z      = gridSize.x * gridSize.y;

        bool isAirX(int index, int ysize, int zsize) {

            int3 dist = distances[index];
            if(dist.y < ysize || dist.z < zsize) return false;

            int a = index;
            int b = index;
            for(int y=1; y<=ysize; y++) {
                a += Y;
                b -= Y;
                if(distances[a].z < zsize) return false;
                if(distances[b].z < zsize) return false;
            }
            a = index;
            b = index;
            for(int z=1; z<=zsize; z++) {
                a += Z;
                b -= Z;
                if(distances[a].y < ysize) return false;
                if(distances[b].y < ysize) return false;
            }
            return true;
        }
        bool isAirY(int index, int xsize, int zsize) {

            int3 dist = distances[index];
            if(dist.x < xsize || dist.z < zsize) return false;

            int a = index;
            int b = index;
            for(int x=1; x<=xsize; x++) {
                a += X;
                b -= X;
                if(distances[a].z < zsize) return false;
                if(distances[b].z < zsize) return false;
            }
            a = index;
            b = index;
            for(int z=1; z<=zsize; z++) {
                a += Z;
                b -= Z;
                if(distances[a].x < xsize) return false;
                if(distances[b].x < xsize) return false;
            }
            return true;
        }
        bool isAirZ(int index, int xsize, int ysize) {

            int3 dist = distances[index];
            if(dist.x < xsize || dist.y < ysize) return false;

            int a = index;
            int b = index;
            for(int x=1; x<=xsize; x++) {
                a += X;
                b -= X;
                if(distances[a].y < ysize) return false;
                if(distances[b].y < ysize) return false;
            }
            a = index;
            b = index;
            for(int y=1; y<=ysize; y++) {
                a += Y;
                b -= Y;
                if(distances[a].x < xsize) return false;
                if(distances[b].x < xsize) return false;
            }
            return true;
        }

        int3 processChunk(Chunk chunk, int index, int3 field) {
            bool gox   = true, goy = true, goz = true;
            int3 limit = distances[index];

            while(gox || goy || goz) {
                /// expand X
                if(gox) {
                    if(field.x<limit.x && isAirX(index+(field.x+1), field.y, field.z) &&
                                          isAirX(index-(field.x+1), field.y, field.z))
                    {
                        field.x++;
                    }
                    else gox = false;
                }
                /// expand Y
                if(goy) {
                    if(field.y<limit.y && isAirY(index+(field.y+1)*Y, field.x, field.z) &&
                                          isAirY(index-(field.y+1)*Y, field.x, field.z))
                    {
                        field.y++;
                    }
                    else goy = false;
                }
                /// expand Z
                if(goz) {
                    if(field.z<limit.z && isAirZ(index+(field.z+1)*Z, field.x, field.y) &&
                                          isAirZ(index-(field.z+1)*Z, field.x, field.y))
                    {
                        field.z++;
                    }
                    else goz = false;
                }
            }

            chunk.setDistance(cast(ubyte)field.x,cast(ubyte)field.y,cast(ubyte)field.z);

            maxDistance = maxDistance.max(field);

            return field;
        }

        /// Traverse all chunks including margin.
        int index = 0;
        int3 prevz = int3(0,0,0);

        for(auto z=chunkMin.z; z<=chunkMax.z; z++) {

            int3 prevy = prevz;

            for(auto y=chunkMin.y; y<=chunkMax.y; y++) {

                int3 prev = prevy;

                for(auto x=chunkMin.x; x<=chunkMax.x; x++) {
                    auto chunk = getChunk(int3(x,y,z));

                    if(chunk.isAir) {
                        prev = processChunk(chunk, index, prev);
                        if(prev.x==0) prev = int3(0,0,0); else prev.x--;
                    } else {
                        prev = int3(0,0,0);
                    }
                    if(x==chunkMin.x) {
                        prevy = prev;
                        if(prevy.y==0) prevy = int3(0,0,0); else prevy.y--;
                    }
                    index++;
                }
                if(y==chunkMin.y) {
                    prevz = prevy;
                    if(prevz.z==0) prevz = int3(0,0,0); else prevz.z--;
                }
            }
        }
    }
}