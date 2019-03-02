module blockie.model.ChunkDistanceFields2;

import blockie.all;
import std.algorithm.searching : minElement, maxElement;
import std.algorithm.iteration : fold;

final class ChunkDistanceFields2 {
private:
    const int RADIUS = 20;
    ChunkStorage storage;
    Chunk[] chunks;
    StopWatch watch;
    Chunk[chunkcoords] map;
    Chunk fakeChunk;
    chunkcoords chunkMin, chunkMax, gridSize;
    int MAX;

    struct Field {
        int up, down;

        bool canContain(Field f) {
            return up >= f.up && down >= f.down;
        }
        string toString() { return "%s-%s".format(up, down); }
    }
    struct Fields {
        Field x,y,z;

        Fields max(Fields f) {
            return Fields(
                Field(.max(x.up, f.x.up), .max(x.down, f.x.down)),
                Field(.max(y.up, f.y.up), .max(y.down, f.y.down)),
                Field(.max(z.up, f.z.up), .max(z.down, f.z.down))
            );
        }
        string toString() { return "[(%s),(%s),(%s)]".format(x, y, z); }
    }
    Fields[] distances;
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
        if(MAX>15) MAX = 15;

        /// store existing non-air chunks
        foreach(c; chunks) {
            map[c.pos] = c;
        }

        this.distances = new Fields[gridSize.hmul()];
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

        Fields maxDistance = Fields();
        int numAirChunks;

        Fields process(int3 chunkPos, int index, Field xstart) {
            Fields f;
            /// x
            for(int i=xstart.up; i<=MAX; i++) {
                if(isAir(chunkPos+int3(i,0,0))) {
                    f.x.up = i;
                } else break;
            }
            for(int i=xstart.down; i<=MAX; i++) {
                if(isAir(chunkPos+int3(-i,0,0))) {
                    f.x.down = i;
                } else break;
            }
            /// y
            for(int i=1; i<=MAX; i++) {
                if(isAir(chunkPos+int3(0,i,0))) {
                    f.y.up = i;
                } else break;
            }
            for(int i=1; i<=MAX; i++) {
                if(isAir(chunkPos+int3(0,-i,0))) {
                    f.y.down = i;
                } else break;
            }
            /// z
            for(int i=1; i<=MAX; i++) {
                if(isAir(chunkPos+int3(0,0,i))) {
                    f.z.up = i;
                } else break;
            }
            for(int i=1; i<=MAX; i++) {
                if(isAir(chunkPos+int3(0,0,-i))) {
                    f.z.down = i;
                } else break;
            }

            distances[index] = f;

            maxDistance = maxDistance.max(f);

            return f;
        }

        int index = 0;

        for(auto z=chunkMin.z; z<=chunkMax.z; z++) {
            for(auto y=chunkMin.y; y<=chunkMax.y; y++) {

                Fields dist;
                Field xstart = Field(1,1);

                for(auto x=chunkMin.x; x<=chunkMax.x; x++) {
                    auto pos   = int3(x,y,z);
                    auto chunk = getChunk(pos);
                    if(chunk.isAir) {
                        numAirChunks++;

                        dist = process(pos, index, xstart);

                        xstart = Field(max(1, dist.x.up-1), max(1, dist.x.down));
                    } else {
                        xstart = Field(1,1);
                    }
                    index++;
                }
            }
        }

        writefln("\tInitial max  = %s", maxDistance);
        writefln("\tnumAirChunks = %s", numAirChunks);
    }
    void processVolumes() {

        auto maxDistance = Fields();
        const int X      = 1;
        const int Y      = gridSize.x;
        const int Z      = gridSize.x * gridSize.y;

        bool isAirX(int index, Field ysize, Field zsize) {

            auto dist = distances[index];

            if(!dist.y.canContain(ysize) ||
               !dist.z.canContain(zsize)) return false;

            int i = index;
            for(int y=1; y<=ysize.up; y++) {
                i += Y;
                if(!distances[i].z.canContain(zsize)) return false;
            }
            i = index;
            for(int y=1; y<=ysize.down; y++) {
                i -= Y;
                if(!distances[i].z.canContain(zsize)) return false;
            }
            i = index;
            for(int z=1; z<=zsize.up; z++) {
                i += Z;
                if(!distances[i].y.canContain(ysize)) return false;
            }
            i = index;
            for(int z=1; z<=zsize.down; z++) {
                i -= Z;
                if(!distances[i].y.canContain(ysize)) return false;
            }
            return true;
        }
        bool isAirY(int index, Field xsize, Field zsize) {

            auto dist = distances[index];

            if(!dist.x.canContain(xsize) ||
               !dist.z.canContain(zsize)) return false;

            int i = index;
            for(int x=1; x<=xsize.up; x++) {
                i += X;
                if(!distances[i].z.canContain(zsize)) return false;
            }
            i = index;
            for(int x=1; x<=xsize.down; x++) {
                i -= X;
                if(!distances[i].z.canContain(zsize)) return false;
            }
            i = index;
            for(int z=1; z<=zsize.up; z++) {
                i += Z;
                if(!distances[i].x.canContain(xsize)) return false;
            }
            i = index;
            for(int z=1; z<=zsize.down; z++) {
                i -= Z;
                if(!distances[i].x.canContain(xsize)) return false;
            }
            return true;
        }
        bool isAirZ(int index, Field xsize, Field ysize) {

            auto dist = distances[index];

            if(!dist.x.canContain(xsize) ||
               !dist.y.canContain(ysize)) return false;

            int i = index;
            for(int x=1; x<=xsize.up; x++) {
                i += X;
                if(!distances[i].y.canContain(ysize)) return false;
            }
            i = index;
            for(int x=1; x<=xsize.down; x++) {
                i -= X;
                if(!distances[i].y.canContain(ysize)) return false;
            }
            i = index;
            for(int y=1; y<=ysize.up; y++) {
                i += Y;
                if(!distances[i].x.canContain(xsize)) return false;
            }
            i = index;
            for(int y=1; y<=ysize.down; y++) {
                i -= Y;
                if(!distances[i].x.canContain(xsize)) return false;
            }
            return true;
        }

        Fields processChunk(Chunk chunk, int index, Fields fields) {
            bool goxup = true, goxdown = true,
                 goyup = true, goydown = true,
                 gozup = true, gozdown = true;

            Fields limits = distances[index];

            while(goxup || goxdown || goyup || goydown || gozup || gozdown) {
                /// expand X
                if(goxup) {
                    if(fields.x.up < limits.x.up &&
                       isAirX(index+(fields.x.up+1), fields.y, fields.z))
                    {
                        fields.x.up++;
                    }
                    else goxup = false;
                }
                if(goxdown) {
                    if(fields.x.down < limits.x.down &&
                       isAirX(index-(fields.x.down+1), fields.y, fields.z))
                    {
                        fields.x.down++;
                    }
                    else goxdown = false;
                }
                /// expand Y
                if(goyup) {
                    if(fields.y.up < limits.y.up &&
                       isAirY(index+(fields.y.up+1)*Y, fields.x, fields.z))
                    {
                        fields.y.up++;
                    }
                    else goyup = false;
                }
                if(goydown) {
                    if(fields.y.down < limits.y.down &&
                       isAirY(index-(fields.y.down+1)*Y, fields.x, fields.z))
                    {
                        fields.y.down++;
                    }
                    else goydown = false;
                }
                /// expand Z
                if(gozup) {
                    if(fields.z.up < limits.z.up &&
                       isAirZ(index+(fields.z.up+1)*Z, fields.x, fields.y))
                    {
                        fields.z.up++;
                    }
                    else gozup = false;
                }
                if(gozdown) {
                    if(fields.z.down < limits.z.down &&
                       isAirZ(index-(fields.z.down+1)*Z, fields.x, fields.y))
                    {
                        fields.z.down++;
                    }
                    else gozdown = false;
                }
            }

            chunk.setDistance(
                cast(ubyte)((fields.x.up<<4) | (fields.x.down)),
                cast(ubyte)((fields.y.up<<4) | (fields.y.down)),
                cast(ubyte)((fields.z.up<<4) | (fields.z.down))
            );

            maxDistance = maxDistance.max(fields);

            return fields;
        }

        /// Traverse all chunks including margin.
        int index = 0;
        Fields prevz = Fields();

        for(auto z=chunkMin.z; z<=chunkMax.z; z++) {

            Fields prevy = prevz;

            for(auto y=chunkMin.y; y<=chunkMax.y; y++) {

                Fields prev = prevy;

                for(auto x=chunkMin.x; x<=chunkMax.x; x++) {
                    auto chunk = getChunk(int3(x,y,z));

                    if(chunk.isAir) {
                        prev = processChunk(chunk, index, prev);
                        if(prev.x.up==0) {
                            prev = Fields();
                        } else {
                            prev.x.up--;
                        }
                    } else {
                        prev = Fields();
                    }
                    if(x==chunkMin.x) {
                        prevy = prev;
                        if(prevy.y.up==0) prevy = Fields(); else prevy.y.up--;
                    }
                    index++;
                }
                if(y==chunkMin.y) {
                    prevz = prevy;
                    if(prevz.z.up==0) prevz = Fields(); else prevz.z.up--;
                }
            }
        }
    }
}