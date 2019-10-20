module blockie.model.DistanceFieldsUniDirCell;

import blockie.all;

final class DistanceFieldsUniDirCell {
private:
    uint MAX;
    ChunkEditView[] views;
    int size, sizeSquared, numRootBits;
    int3 minChunkPos, maxChunkPos;

    ChunkEditView fakeView;
    ChunkData fakeChunkData;
    StopWatch watch;

    struct ChunkData {
        ChunkEditView view;
        ubyte[] x;
        ubyte[] y;
        ubyte[] z;
    }
    ChunkData[chunkcoords] chunkMap;
public:
    this(ChunkEditView[] views, uint cellsPerSide, uint max) {
        this.views       = views;
        this.MAX         = max;
        this.size        = cellsPerSide;
        this.sizeSquared = size*size;
        this.numRootBits = From!"core.bitop".bsf(cellsPerSide);

        //writefln("size=%s, numRootBits=%s", size, numRootBits);

        if(views.length>0) {

            this.fakeView = new FakeEditView;

            this.fakeChunkData = ChunkData(
                fakeView,
                new ubyte[size*size*size],
                new ubyte[size*size*size],
                new ubyte[size*size*size]
            );
            fakeChunkData.x[] = cast(ubyte)MAX;
            fakeChunkData.y[] = cast(ubyte)MAX;
            fakeChunkData.z[] = cast(ubyte)MAX;

            this.minChunkPos = int3(int.max);
            this.maxChunkPos = int3(int.min);

            foreach(v; views) {
                chunkMap[v.pos] = ChunkData(
                    v,
                    new ubyte[size*size*size],
                    new ubyte[size*size*size],
                    new ubyte[size*size*size]
                );

                minChunkPos = minChunkPos.min(v.pos);
                maxChunkPos = maxChunkPos.max(v.pos);
            }
            chunkMap.rehash();

            writefln("minChunkPos = %s, maxChunkPos = %s", minChunkPos, maxChunkPos);
        }
    }
    auto generate() {
        if(chunkMap.length==0) return this;

        writefln("Generating cell distances {"); flushConsole();

        StopWatch totalTime;
        totalTime.start();

        watch.start();
        calculateInitialDistances();
        watch.stop();
        writefln("\tInitial distances took %.2f seconds", watch.peek().total!"nsecs"*1e-09);
        flushConsole();

        watch.reset(); watch.start();
        processVolumes();
        watch.stop();
        writefln("\tProcessing volumes took %.2f seconds", watch.peek().total!"nsecs"*1e-09);
        flushConsole();

        totalTime.stop();
        writefln("\tTotal time to generate cell distances ... (%.2f seconds)", totalTime.peek().total!"nsecs"*1e-09);
        writefln("}");
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
        /// root = 1 bits -> 2
        /// root = 2 bits -> 4
        /// root = 3 bits -> 8
        /// root = 4 bits -> 16
        /// root = 5 bits -> 32
        //expect(p.allLT(size) && p.allGTE(0));
        return p.dot(int3(1, size, sizeSquared));
    }
    /// In global cellcoords
    bool isAirCell(int3 cellCoords) {
        auto chunkpos   = cellCoords>>numRootBits;
        ChunkData data  = getChunkData(chunkpos);
        auto view       = data.view;
        if(view.isAir) return true;

        int3 rem = cellCoords-(chunkpos<<numRootBits);
        uint oct = getOctree(rem);
        return view.isAirCell(oct);
    }
    void calculateInitialDistances() {

        auto maxDistance = int3(0,0,0);

        /**
         * Set max air distance for cell (for each dimension, volumes are not considered here)
         *  eg.  x0x  = 0 distance (x direction)
         *      x000x = 1 distance (x direction)
         */
        int3 _processCell(ChunkData data, int3 cellOffset, int xstart, int ystart, int zstart) {
            auto view       = data.view;
            const cellCoord = (view.pos<<numRootBits)+cellOffset;
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

        foreach(k,data; chunkMap) {

            auto view = data.view;
            if(!view.isAir) {

                ystart[] = 1;
                int yoffset = 0;

                for(int z=0; z<size; z++) {

                    for(int y=0; y<size; y++) {

                        int3 dist;
                        int xstart = 1;

                        for(int x=0; x<size; x++) {
                            auto p = int3(x,y,z);

                            if(view.isAirCell(getOctree(p))) {
                                dist   = _processCell(data, p, xstart, ystart[yoffset+x], 1);
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
    /** In global cellcoords */
    int3 getDist(int3 cellCoords) {
        auto chunkpos   = cellCoords>>numRootBits;
        ChunkData data  = getChunkData(chunkpos);
        auto view       = data.view;

        if(view is fakeView) {
            return int3(MAX, MAX, MAX);
        }

        int3 offset = cellCoords-(chunkpos<<numRootBits);
        int oct     = getOctree(offset);
        return int3(data.x[oct], data.y[oct], data.z[oct]);
    }
    //void chat(A...)(lazy string fmt, lazy A args) {
    //    if(count==0) {
    //        writefln(format(fmt, args)); flushConsole();
    //    }
    //}
    void processVolumes() {

        auto maxDistance = int3(0,0,0);

        uint _volumeOf(int3 i) {
            return (i*2+1).hmul();
        }
        bool _isAirX(int3 coord, int ysize, int zsize) {

            int3 cell = getDist(coord);
            if(cell.y < ysize || cell.z < zsize) return false;

            int3 a = coord;
            for(int y=1; y<=ysize; y++) {
                a.y++;
                if(getDist(a).z < zsize) return false;
            }
            a = coord;
            for(int y=1; y<=ysize; y++) {
                a.y--;
                if(getDist(a).z < zsize) return false;
            }

            /* If we are outside the chunk range we default to a distance field of (max,max,max)
               which means we need to double check ZY here to avoid artifacts. (Could also be fixed by
               adding surrounding dummy views which we perform calculateInitialDistances() on) */
            a = coord;
            for(int z=1; z<=zsize; z++) {
                a.z++;
                if(getDist(a).y < ysize) return false;
            }
            a = coord;
            for(int z=1; z<=zsize; z++) {
                a.z--;
                if(getDist(a).y < ysize) return false;
            }
            return true;
        }
        bool _isAirY(int3 coord, int xsize, int zsize) {

            int3 cell = getDist(coord);
            if(cell.x < xsize || cell.z < zsize) return false;

            int3 a = coord;
            for(int x=1; x<=xsize; x++) {
                a.x++;
                if(getDist(a).z < zsize) return false;
            }
            a = coord;
            for(int x=1; x<=xsize; x++) {
                a.x--;
                if(getDist(a).z < zsize) return false;
            }

            /* If we are outside the chunk range we default to a distance field of (max,max,max)
               which means we need to double check ZX here to avoid artifacts. (Could also be fixed by
               adding surrounding dummy views which we perform calculateInitialDistances() on) */
            a = coord;
            for(int z=1; z<=zsize; z++) {
                a.z++;
                if(getDist(a).x < xsize) return false;
            }
            a = coord;
            for(int z=1; z<=zsize; z++) {
                a.z--;
                if(getDist(a).x < xsize) return false;
            }
            return true;
        }
        bool _isAirZ(int3 coord, int xsize, int ysize) {

            int3 cell = getDist(coord);
            if(cell.x < xsize || cell.y < ysize) return false;

            int3 a = coord;
            for(int x=1; x<=xsize; x++) {
                a.x++;
                if(getDist(a).y < ysize) return false;
            }
            a = coord;
            for(int x=1; x<=xsize; x++) {
                a.x--;
                if(getDist(a).y < ysize) return false;
            }
            /* If we are outside the chunk range we default to a distance field of (max,max,max)
               which means we need to double check YX here to avoid artifacts. (Could also be fixed by
               adding surrounding dummy views which we perform calculateInitialDistances() on) */
            a = coord;
            for(int y=1; y<=ysize; y++) {
                a.y++;
                if(getDist(a).x < xsize) return false;
            }
            a = coord;
            for(int y=1; y<=ysize; y++) {
                a.y--;
                if(getDist(a).x < xsize) return false;
            }
            return true;
        }

        int3 _processCellInner(ChunkData data, int3 cellOffset, int3 field, int order) {

            auto view       = data.view;
            const cellCoord = (view.pos<<numRootBits)+cellOffset;
            const oct       = getOctree(cellOffset);
            const limit     = int3(data.x[oct], data.y[oct], data.z[oct]);

            bool gox = true, goy = true, goz = true;

            void _expandX() {
                if(!gox) return;
                if(field.x<limit.x && _isAirX(cellCoord + int3(field.x+1,0,0), field.y, field.z) &&
                                      _isAirX(cellCoord - int3(field.x+1,0,0), field.y, field.z))
                {
                    field.x++;
                }
                else gox = false;
            }
            void _expandY() {
                if(!goy) return;
                if(field.y<limit.y && _isAirY(cellCoord + int3(0,field.y+1,0), field.x, field.z) &&
                                      _isAirY(cellCoord - int3(0,field.y+1,0), field.x, field.z))
                {
                    field.y++;
                }
                else goy = false;
            }
            void _expandZ() {
                if(!goz) return;
                if(field.z<limit.z && _isAirZ(cellCoord + int3(0,0,field.z+1), field.x, field.y) &&
                                      _isAirZ(cellCoord - int3(0,0,field.z+1), field.x, field.y))
                {
                    field.z++;
                }
                else goz = false;
            }

            while(gox || goy || goz) {
                switch(order) {
                    case 0:
                        _expandX();
                        _expandY();
                        _expandZ();
                        break;
                    case 1:
                        _expandX();
                        _expandZ();
                        _expandY();
                        break;
                    case 2:
                        _expandY();
                        _expandX();
                        _expandZ();
                        break;
                    case 3:
                        _expandZ();
                        _expandX();
                        _expandY();
                        break;
                    case 4:
                        _expandY();
                        _expandZ();
                        _expandX();
                        break;
                    default:
                        _expandZ();
                        _expandY();
                        _expandX();
                        break;
                }
            }

            return field;
        }
        int3 _processCell(ChunkData data, int3 cellOffset, int3 field) {

            uint bestVolume = 0;
            int3 bestField;
            for(auto i=0; i<6; i++) {

                auto f = _processCellInner(data, cellOffset, field, i);
                auto v = _volumeOf(f);

                if(v>=bestVolume) {
                    bestVolume = v;
                    bestField  = f;
                }
            }

            const oct = getOctree(cellOffset);
            data.view.setCellDistance(oct, cast(ubyte)bestField.x,
                                           cast(ubyte)bestField.y,
                                           cast(ubyte)bestField.z);

            maxDistance = maxDistance.max(bestField);

            return bestField;
        }

        ulong volume = 0;
        foreach(k,v; chunkMap) {
            //writefln("\tChunk %s of %s", ++i, views.length); flushConsole();

            auto view = v.view;
            if(!view.isAir) {

                int3 prevz = int3(0,0,0);

                for(int z=0; z<size; z++) {

                    int3 prevy = prevz;

                    for(int y=0; y<size; y++) {

                        int3 prev = prevy;

                        for(int x=0; x<size; x++) {
                            auto p = int3(x,y,z);

                            if(view.isAirCell(getOctree(p))) {

                                prev    = _processCell(v, p, prev);
                                volume += _volumeOf(prev);

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
        writefln("\tVolume = %000,s", volume);
    }
}