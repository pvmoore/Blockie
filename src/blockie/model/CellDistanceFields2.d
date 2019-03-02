module blockie.model.CellDistanceFields2;

import blockie.all;

/// SIZE:
/// root = 4 bits -> 16
/// root = 5 bits -> 32
///
///
///
///
///
///
///
final class CellDistanceFields2 {
private:
    const uint MAX = 255;
    Chunk[] chunks;
    Model model;
    int size, sizeSquared;
    Chunk fakeChunk;
    ChunkData fakeChunkData;
    StopWatch watch;

    struct ChunkData {
        Chunk chunk;
        ubyte[] x;
        ubyte[] y;
        ubyte[] z;
    }
    ChunkData[chunkcoords] chunkMap;
public:
    this(Chunk[] chunks, Model model) {
        this.chunks      = chunks;
        this.model       = model;
        this.size        = 1<<model.numRootBits();
        this.sizeSquared = size*size;

        if(chunks.length>0) {

            this.fakeChunk = model.makeChunk(chunkcoords(int.min));

            this.fakeChunkData = ChunkData(
                fakeChunk,
                new ubyte[size*size*size],
                new ubyte[size*size*size],
                new ubyte[size*size*size]
            );
            fakeChunkData.x[] = cast(ubyte)MAX;
            fakeChunkData.y[] = cast(ubyte)MAX;
            fakeChunkData.z[] = cast(ubyte)MAX;

            foreach (c; chunks) {
                chunkMap[c.pos] = ChunkData(
                    c,
                    new ubyte[size*size*size],
                    new ubyte[size*size*size],
                    new ubyte[size*size*size]
                );
            }
            chunkMap.rehash();
        }
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

        int3 maxDistance = int3(0,0,0);

        int3 processCell(ChunkData data, int3 cellOffset, int xstart, int ystart, int zstart) {
            Chunk chunk    = data.chunk;
            int3 cellCoord = (chunk.pos<<model.numRootBits())+cellOffset;
            int x,y,z;

            /// x
            for(int i=xstart; i<=MAX; i++) {
                if(isAirCell(cellCoord+int3(i,0,0)) && isAirCell(cellCoord+int3(-i,0,0))) {
                    x = i;
                } else break;
            }

            /// y
            for(int i=ystart; i<=MAX; i++) {
                if(isAirCell(cellCoord+int3(0,i,0)) && isAirCell(cellCoord+int3(0,-i,0))) {
                    y = i;
                } else break;
            }

            /// z
            for(int i=zstart; i<=MAX; i++) {
                if(isAirCell(cellCoord+int3(0,0,i)) && isAirCell(cellCoord+int3(0,0,-i))) {
                    z = i;
                } else break;
            }

            int oct = getOctree(cellOffset);
            data.x[oct] = cast(ubyte)x;
            data.y[oct] = cast(ubyte)y;
            data.z[oct] = cast(ubyte)z;

            maxDistance = maxDistance.max(int3(x,y,z));

            return int3(x,y,z);
        }

        int[] ystart = new int[size*size];

        foreach(k,v; chunkMap) {

            auto chunk = v.chunk;
            if(!chunk.isAir) {

                ystart[] = 1;
                int yoffset = 0;

                for(int z=0; z<size; z++) {

                    for(int y=0; y<size; y++) {

                        int3 dist;
                        int xstart = 1;

                        for(int x=0; x<size; x++) {
                            auto p = int3(x,y,z);

                            if(chunk.isAirCell(getOctree(p))) {
                                dist   = processCell(v, p, xstart, ystart[yoffset+x], 1);
                                xstart = max(1, dist.x-1);
                            } else {
                                dist   = int3(1,1,1);
                                xstart = 1;
                            }

                            ystart[yoffset+x] = max(1, dist.y-1);
                        }
                    }
                    yoffset += size;
                }
            }
        }
        writefln("\tmaxDistance %s", maxDistance);
    }

    /// In global cellcoords
    int3 getCell(int3 cellCoords) {

        auto chunkpos   = cellCoords>>model.numRootBits();
        ChunkData data  = getChunkData(chunkpos);
        Chunk chunk     = data.chunk;

        if(chunk is fakeChunk) {
            return int3(MAX, MAX, MAX);
        }

        int3 offset = cellCoords-(chunkpos<<model.numRootBits());
        int oct     = getOctree(offset);
        return int3(data.x[oct], data.y[oct], data.z[oct]);
    }
    //void chat(A...)(lazy string fmt, lazy A args) {
    //    if(count==0) {
    //        writefln(format(fmt, args)); flushConsole();
    //    }
    //}
    void processVolumes() {

        int3 maxDistance = int3(0,0,0);

        bool isAirX(int3 coord, int ysize, int zsize) {

            int3 cell = getCell(coord);
            if(cell.y < ysize || cell.z < zsize) return false;

            int3 a = coord;
            for(int y=1; y<=ysize; y++) {
                a.y++;
                if(getCell(a).z < zsize) return false;
            }
            a = coord;
            for(int y=1; y<=ysize; y++) {
                a.y--;
                if(getCell(a).z < zsize) return false;
            }
            a = coord;
            for(int z=1; z<=zsize; z++) {
                a.z++;
                if(getCell(a).y < ysize) return false;
            }
            a = coord;
            for(int z=1; z<=zsize; z++) {
                a.z--;
                if(getCell(a).y < ysize) return false;
            }
            return true;
        }
        bool isAirY(int3 coord, int xsize, int zsize) {

            int3 cell = getCell(coord);
            if(cell.x < xsize || cell.z < zsize) return false;

            int3 a = coord;
            for(int x=1; x<=xsize; x++) {
                a.x++;
                if(getCell(a).z < zsize) return false;
            }
            a = coord;
            for(int x=1; x<=xsize; x++) {
                a.x--;
                if(getCell(a).z < zsize) return false;
            }
            a = coord;
            for(int z=1; z<=zsize; z++) {
                a.z++;
                if(getCell(a).x < xsize) return false;
            }
            a = coord;
            for(int z=1; z<=zsize; z++) {
                a.z--;
                if(getCell(a).x < xsize) return false;
            }
            return true;
        }
        bool isAirZ(int3 coord, int xsize, int ysize) {

            int3 cell = getCell(coord);
            if(cell.x < xsize || cell.y < ysize) return false;

            int3 a = coord;
            for(int x=1; x<=xsize; x++) {
                a.x++;
                if(getCell(a).y < ysize) return false;
            }
            a = coord;
            for(int x=1; x<=xsize; x++) {
                a.x--;
                if(getCell(a).y < ysize) return false;
            }
            a = coord;
            for(int y=1; y<=ysize; y++) {
                a.y++;
                if(getCell(a).x < xsize) return false;
            }
            a = coord;
            for(int y=1; y<=ysize; y++) {
                a.y--;
                if(getCell(a).x < xsize) return false;
            }
            return true;
        }

        int3 processCell(ChunkData data, int3 cellOffset, int3 field) {

            Chunk chunk    = data.chunk;
            int3 cellCoord = (chunk.pos<<model.numRootBits())+cellOffset;
            uint oct       = getOctree(cellOffset);
            int3 limit     = int3(data.x[oct], data.y[oct], data.z[oct]);

            bool gox = true, goy = true, goz = true;

            while(gox || goy || goz) {
                /// expand X
                if(gox) {
                    if(field.x<limit.x && isAirX(cellCoord + int3(field.x+1,0,0), field.y, field.z) &&
                                          isAirX(cellCoord - int3(field.x+1,0,0), field.y, field.z))
                    {
                        field.x++;
                    }
                    else gox = false;
                }
                /// expand Y
                if(goy) {
                    if(field.y<limit.y && isAirY(cellCoord + int3(0,field.y+1,0), field.x, field.z) &&
                                          isAirY(cellCoord - int3(0,field.y+1,0), field.x, field.z))
                    {
                        field.y++;
                    }
                    else goy = false;
                }
                /// expand Z
                if(goz) {
                    if(field.z<limit.z && isAirZ(cellCoord + int3(0,0,field.z+1), field.x, field.y) &&
                                          isAirZ(cellCoord - int3(0,0,field.z+1), field.x, field.y))
                    {
                        field.z++;
                    }
                    else goz = false;
                }
            }

            chunk.setCellDistance(oct, cast(ubyte)field.x,cast(ubyte)field.y,cast(ubyte)field.z);

            maxDistance = maxDistance.max(field);

            return field;
        }

        int i=0;
        foreach(k,v; chunkMap) {
            writefln("\tChunk %s of %s", ++i, chunks.length); flushConsole();

            auto chunk = v.chunk;
            if(!chunk.isAir) {

                int3 prevz = int3(0,0,0);

                for(int z=0; z<size; z++) {

                    int3 prevy = prevz;

                    for(int y=0; y<size; y++) {

                        int3 prev = prevy;

                        for(int x=0; x<size; x++) {
                            auto p = int3(x,y,z);

                            if(chunk.isAirCell(getOctree(p))) {
                                prev = processCell(v, p, prev);

                                if(prev.x==0) prev = int3(0,0,0); else prev.x--;

                            } else {
                                prev = int3(0,0,0);
                            }

                            if(x==0) {
                                prevy = prev;
                                if(prevy.y==0) prevy = int3(0,0,0); else prevy.y--;
                            }
                        }

                        if(y==0) {
                            prevz = prevy;
                            if(prevz.z==0) prevz = int3(0,0,0); else prevz.z--;
                        }
                    }
                }
            }
        }
        writefln("\tmaxDistance %s", maxDistance);
    }
}