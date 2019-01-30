module blockie.model.CellDistanceFieldsDirectional;

import blockie.all;
/**
 *  xyz distance directional fields. Assumes we have 4 bits per direction/axis
 *
 */
final class CellDistanceFieldsDirectional {
private:
    Chunk[] chunks;
    Model model;
    int size, sizeSquared;
    Chunk fakeChunk;
    ChunkData fakeChunkData;
    StopWatch watch;

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

    struct ChunkData {
        Chunk chunk;
        Fields[] f;
    }
    ChunkData[chunkcoords] chunkMap;
    Fields fakeFields;
    uint[16] DISTANCE_TABLE;
    uint MAX = 30;
public:
    this(Chunk[] chunks, Model model) {
        this.chunks      = chunks;
        this.model       = model;
        this.size        = 1<<model.numRootBits();
        this.sizeSquared = size*size;
        this.fakeFields  = Fields(Field(MAX,MAX), Field(MAX,MAX), Field(MAX,MAX));

        if(chunks.length>0) {

            this.fakeChunk = model.makeChunk(chunkcoords(int.min));

            this.fakeChunkData = ChunkData(fakeChunk, null);

            foreach (c; chunks) {
                chunkMap[c.pos] = ChunkData(
                    c,
                    new Fields[size*size*size]
                );
            }
            chunkMap.rehash();
        }
        for(int i=0;i<16;i++) {
            float f = i;
            DISTANCE_TABLE[i] = cast(uint)From!"std.math".floor(f + f*f*0.03f);
        }
        MAX = DISTANCE_TABLE[15];

        writefln("          [0, 1, 2, 3, 4, 5, 6,  7, 8, 9, 10, 11, 12, 13, 14, 15]");
        writefln("DISTANCES=%s", DISTANCE_TABLE);
        writefln("MAX = %s", MAX);
    }
    auto generate() {
        if(chunkMap.length==0) return this;

        writefln("\nGenerating cell distances ..."); flushConsole();

        watch.start();
        calculateInitialDistances();
        watch.stop();
        writefln("\tInitial distances took %.2f seconds", watch.peek().total!"nsecs"*1e-09);

        watch.reset(); watch.start();
        processVolumes();

        watch.stop();
        writefln("\tProcessing volumes took %.2f seconds", watch.peek().total!"nsecs"*1e-09);
        return this;
    }
private:
    ChunkData cachedData;
    int3 cachedCoord = int3(int.max, int.max, int.max);

    ChunkData getChunkData(chunkcoords p) {
        if(p==cachedCoord) {
            return cachedData;
        }
        cachedCoord = p;

        auto ptr = p in chunkMap;
        if(ptr) {
            cachedData = (*ptr);
            return cachedData;
        }
        cachedData = fakeChunkData;
        return cachedData;
    }
    uint getOctree(int3 p) {
        /// root = 4 bits -> 16
        /// root = 5 bits -> 32
        assert(p.allLT(size) && p.allGTE(0));
        return p.dot(int3(1, size, sizeSquared));
    }
    /// In global cellcoords
    bool isAirCell(int3 cellCoords) {
        auto chunkpos   = cellCoords>>model.numRootBits();
        ChunkData data  = getChunkData(chunkpos);
        Chunk chunk     = data.chunk;
        if(chunk.isAir) return true;

        int3 rem = cellCoords-(chunkpos<<model.numRootBits());
        uint oct = getOctree(rem);
        return chunk.isAirCell(oct);
    }
    void calculateInitialDistances() {

        Fields maxDistance = Fields();

        Fields processCell(ChunkData data, int3 cellOffset, Field xstart, Field ystart) {
            Chunk chunk    = data.chunk;
            int3 cellCoord = (chunk.pos<<model.numRootBits())+cellOffset;
            Fields f;

            /// x
            for(int i=xstart.up; i<=MAX; i++) {
                if(isAirCell(cellCoord+int3(i,0,0))) {
                    f.x.up = i;
                } else break;
            }
            for(int i=xstart.down; i<=MAX; i++) {
                if(isAirCell(cellCoord+int3(-i,0,0))) {
                    f.x.down = i;
                } else break;
            }

            /// y
            for(int i=ystart.up; i<=MAX; i++) {
                if(isAirCell(cellCoord+int3(0,i,0))) {
                    f.y.up = i;
                } else break;
            }
            for(int i=ystart.down; i<=MAX; i++) {
                if(isAirCell(cellCoord+int3(0,-i,0))) {
                    f.y.down = i;
                } else break;
            }

            /// z
            for(int i=1; i<=MAX; i++) {
                if(isAirCell(cellCoord+int3(0,0,i))) {
                    f.z.up = i;
                } else break;
            }
            for(int i=1; i<=MAX; i++) {
                if(isAirCell(cellCoord+int3(0,0,-i))) {
                    f.z.down = i;
                } else break;
            }

            int oct = getOctree(cellOffset);
            data.f[oct] = f;

            maxDistance = maxDistance.max(f);

            return f;
        }

        Field[] ystart = new Field[size*size];

        foreach(k,v; chunkMap) {

            auto chunk = v.chunk;
            if(!chunk.isAir) {

                for(int i=0;i<ystart.length;i++) ystart[i] = Field(1,1);
                int yoffset = 0;

                for(int z=0; z<size; z++) {

                    for(int y=0; y<size; y++) {

                        Fields dist;
                        Field xstart = Field(1,1);

                        for(int x=0; x<size; x++) {
                            auto p = int3(x,y,z);

                            if(chunk.isAirCell(getOctree(p))) {

                                dist = processCell(v, p, xstart, ystart[yoffset+x]);

                                xstart            = Field(max(1, dist.x.up-1), max(1, dist.x.down));
                                ystart[yoffset+x] = Field(max(1, dist.y.up-1), max(1, dist.y.down));
                            } else {
                                xstart            = Field(1,1);
                                ystart[yoffset+x] = Field(1,1);
                            }
                        }
                    }
                    yoffset += size;
                }
            }
        }
        writefln("\tmaxDistance %s", maxDistance);
    }

    /// In global cellcoords
    Fields getDistance(int3 cellCoords) {

        auto chunkpos   = cellCoords>>model.numRootBits();
        ChunkData data  = getChunkData(chunkpos);
        Chunk chunk     = data.chunk;

        if(chunk is fakeChunk) {
            return fakeFields;
        }

        int3 offset = cellCoords-(chunkpos<<model.numRootBits());
        int oct     = getOctree(offset);
        return data.f[oct];
    }
    //void chat(A...)(lazy string fmt, lazy A args) {
    //    if(count==0) {
    //        writefln(format(fmt, args)); flushConsole();
    //    }
    //}
    void setDistance(Chunk chunk, uint oct, Fields f) {

        int convert(int v) {
            long r = 0;
            foreach(i, n; DISTANCE_TABLE) {
                if(v>=n) r = i;
            }
            return cast(int)r;
        }

        chunk.setCellDistance(oct,
            cast(ubyte)((convert(f.x.up)<<4) | convert(f.x.down)),
            cast(ubyte)((convert(f.y.up)<<4) | convert(f.y.down)),
            cast(ubyte)((convert(f.z.up)<<4) | convert(f.z.down))
        );
    }
    void processVolumes() {

        Fields maxDistance = Fields();

        bool isAirX(int3 coord, Field ysize, Field zsize) {

            Fields dist = getDistance(coord);
            if(!dist.y.canContain(ysize) || !dist.z.canContain(zsize)) return false;

            int3 a = coord;
            for(int y=1; y<=ysize.up; y++) {
                a.y++;
                if(!getDistance(a).z.canContain(zsize)) return false;
            }
            a = coord;
            for(int y=1; y<=ysize.down; y++) {
                a.y--;
                if(!getDistance(a).z.canContain(zsize)) return false;
            }
            a = coord;
            for(int z=1; z<=zsize.up; z++) {
                a.z++;
                if(!getDistance(a).y.canContain(ysize)) return false;
            }
            a = coord;
            for(int z=1; z<=zsize.down; z++) {
                a.z--;
                if(!getDistance(a).y.canContain(ysize)) return false;
            }
            return true;
        }
        bool isAirY(int3 coord, Field xsize, Field zsize) {

            Fields dist = getDistance(coord);
            if(!dist.x.canContain(xsize) || !dist.z.canContain(zsize)) return false;

            int3 a = coord;
            for(int x=1; x<=xsize.up; x++) {
                a.x++;
                if(!getDistance(a).z.canContain(zsize)) return false;
            }
            a = coord;
            for(int x=1; x<=xsize.down; x++) {
                a.x--;
                if(!getDistance(a).z.canContain(zsize)) return false;
            }
            a = coord;
            for(int z=1; z<=zsize.up; z++) {
                a.z++;
                if(!getDistance(a).x.canContain(xsize)) return false;
            }
            a = coord;
            for(int z=1; z<=zsize.down; z++) {
                a.z--;
                if(!getDistance(a).x.canContain(xsize)) return false;
            }
            return true;
        }
        bool isAirZ(int3 coord, Field xsize, Field ysize) {

            Fields dist = getDistance(coord);
            if(!dist.x.canContain(xsize) || !dist.y.canContain(ysize)) return false;

            int3 a = coord;
            for(int x=1; x<=xsize.up; x++) {
                a.x++;
                if(!getDistance(a).y.canContain(ysize)) return false;
            }
            a = coord;
            for(int x=1; x<=xsize.down; x++) {
                a.x--;
                if(!getDistance(a).y.canContain(ysize)) return false;
            }
            a = coord;
            for(int y=1; y<=ysize.up; y++) {
                a.y++;
                if(!getDistance(a).x.canContain(xsize)) return false;
            }
            a = coord;
            for(int y=1; y<=ysize.down; y++) {
                a.y--;
                if(!getDistance(a).x.canContain(xsize)) return false;
            }
            return true;
        }

        Fields processCell(ChunkData data, int3 cellOffset, Fields fields) {

            Chunk chunk    = data.chunk;
            int3 cellCoord = (chunk.pos<<model.numRootBits())+cellOffset;
            uint oct       = getOctree(cellOffset);
            Fields limits  = data.f[oct];

            bool goxup = true, goyup = true, gozup = true;
            bool goxdown = true, goydown = true, gozdown = true;

            while(goxup || goxdown || goyup || goydown || gozup || gozdown) {
                /// expand X
                if(goxup) {
                    if(fields.x.up < limits.x.up &&
                       isAirX(cellCoord + int3(fields.x.up+1,0,0), fields.y, fields.z))
                    {
                        fields.x.up++;
                    }
                    else goxup = false;
                }
                if(goxdown) {
                    if(fields.x.down < limits.x.down &&
                       isAirX(cellCoord - int3(fields.x.down+1,0,0), fields.y, fields.z))
                    {
                        fields.x.down++;
                    }
                    else goxdown = false;
                }

                /// expand Y
                if(goyup) {
                    if(fields.y.up < limits.y.up &&
                       isAirY(cellCoord + int3(0,fields.y.up+1,0), fields.x, fields.z))
                    {
                        fields.y.up++;
                    }
                    else goyup = false;
                }
                if(goydown) {
                    if(fields.y.down < limits.y.down &&
                       isAirY(cellCoord - int3(0,fields.y.down+1,0), fields.x, fields.z))
                    {
                        fields.y.down++;
                    }
                    else goydown = false;
                }

                /// expand Z
                if(gozup) {
                    if(fields.z.up < limits.z.up &&
                       isAirZ(cellCoord + int3(0,0,fields.z.up+1), fields.x, fields.y))
                    {
                        fields.z.up++;
                    }
                    else gozup = false;
                }
                if(gozdown) {
                    if(fields.z.down < limits.z.down &&
                       isAirZ(cellCoord - int3(0,0,fields.z.down+1), fields.x, fields.y))
                    {
                        fields.z.down++;
                    }
                    else gozdown = false;
                }
            }

            setDistance(chunk, oct, fields);

            maxDistance = maxDistance.max(fields);

            return fields;
        }

        int i=0;
        foreach(k,v; chunkMap) {
            writefln("\tChunk %s of %s", ++i, chunks.length); flushConsole();

            auto chunk = v.chunk;
            if(!chunk.isAir) {

                Fields prevz = Fields();

                for(int z=0; z<size; z++) {

                    Fields prevy = prevz;

                    for(int y=0; y<size; y++) {

                        Fields prev = prevy;

                        for(int x=0; x<size; x++) {
                            auto p = int3(x,y,z);

                            if(chunk.isAirCell(getOctree(p))) {
                                prev = processCell(v, p, prev);

                                if(prev.x.up==0) prev = Fields(); else prev.x.up--;

                            } else {
                                prev = Fields();
                            }

                            if(x==0) {
                                prevy = prev;
                                if(prevy.y.up==0) prevy = Fields(); else prevy.y.up--;
                            }
                        }

                        if(y==0) {
                            prevz = prevy;
                            if(prevz.z.up==0) prevz = Fields(); else prevz.z.up--;
                        }
                    }
                }
            }
        }
        writefln("\tmaxDistance %s", maxDistance);
    }
}