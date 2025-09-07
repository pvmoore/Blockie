module blockie.model.DistanceFieldsBiDirCell;

import blockie.model;
/**
 *  xyz bi-directional distance fields.
 */
final class DistanceFieldsBiDirCell {
private:
    ChunkEditView[] views;
    int size, sizeSquared, numRootBits;
    ChunkEditView fakeView;
    ChunkData fakeChunkData;
    StopWatch watch;

    struct ChunkData {
        ChunkEditView view;
        DFieldsBi[] f;
    }
    ChunkData[chunkcoords] chunkMap;
    DFieldsBi fakeFields;
    uint[16] DISTANCE_TABLE;
    uint MAX;
public:
    this(ChunkEditView[] views,  uint cellsPerSide, uint max) {
        this.views       = views;
        this.size        = cellsPerSide;
        this.sizeSquared = size*size;
        this.numRootBits = From!"core.bitop".bsf(cellsPerSide);

        //writefln("size=%s, numRootBits=%s", size, numRootBits);

        this.fakeFields  = DFieldsBi(DFieldBi(MAX,MAX), DFieldBi(MAX,MAX), DFieldBi(MAX,MAX));
        this.MAX         = max;

        if(views.length>0) {

            this.fakeView = new FakeEditView;

            this.fakeChunkData = ChunkData(fakeView, null);

            foreach(v; views) {
                chunkMap[v.pos] = ChunkData(
                    v,
                    new DFieldsBi[size*size*size]
                );
            }
            chunkMap.rehash();
        }
    }
    auto generate() {
        if(chunkMap.length==0) return this;

        writefln("Generating cell distances (max = %s) {", MAX); flushConsole();

        watch.start();
        calculateInitialDistances();
        watch.stop();
        writefln("\tInitial distances took %.2f seconds", watch.peek().total!"nsecs"*1e-09);
        flushConsole();

        watch.reset(); watch.start();
        processVolumes();

        watch.stop();
        writefln("\tProcessing volumes took %.2f seconds", watch.peek().total!"nsecs"*1e-09);
        writefln("}");
        flushConsole();
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
        auto chunkpos  = cellCoords>>numRootBits;
        ChunkData data = getChunkData(chunkpos);
        auto view      = data.view;
        if(view.isAir) return true;

        int3 rem = cellCoords-(chunkpos<<numRootBits);
        uint oct = getOctree(rem);
        return view.isAirCell(oct);
    }
    void calculateInitialDistances() {

        auto maxDistance = DFieldsBi();

        DFieldsBi processCell(ChunkData data,
                              int3 cellOffset,
                              DFieldBi xstart,
                              DFieldBi ystart)
        {
            auto view      = data.view;
            int3 cellCoord = (view.pos<<numRootBits)+cellOffset;
            DFieldsBi f;

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

        auto ystart = new DFieldBi[size*size];

        foreach(k,v; chunkMap) {

            auto view = v.view;
            if(!view.isAir) {

                for(int i=0;i<ystart.length;i++) ystart[i] = DFieldBi(1,1);
                int yoffset = 0;

                for(int z=0; z<size; z++) {

                    for(int y=0; y<size; y++) {

                        DFieldsBi dist;
                        auto xstart = DFieldBi(1,1);

                        for(int x=0; x<size; x++) {
                            auto p = int3(x,y,z);

                            if(view.isAirCell(getOctree(p))) {

                                dist = processCell(v, p, xstart, ystart[yoffset+x]);

                                xstart            = DFieldBi(maxOf(1, dist.x.up-1), maxOf(1, dist.x.down));
                                ystart[yoffset+x] = DFieldBi(maxOf(1, dist.y.up-1), maxOf(1, dist.y.down));
                            } else {
                                xstart            = DFieldBi(1,1);
                                ystart[yoffset+x] = DFieldBi(1,1);
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
    DFieldsBi getDistance(int3 cellCoords) {

        auto chunkpos   = cellCoords>>numRootBits;
        ChunkData data  = getChunkData(chunkpos);
        auto view       = data.view;

        if(view is fakeView) {
            return fakeFields;
        }

        int3 offset = cellCoords-(chunkpos<<numRootBits);
        int oct     = getOctree(offset);
        return data.f[oct];
    }
    //void chat(A...)(lazy string fmt, lazy A args) {
    //    if(count==0) {
    //        writefln(format(fmt, args)); flushConsole();
    //    }
    //}

    void processVolumes() {

        bool isAirX(int3 coord, DFieldBi ysize, DFieldBi zsize) {

            DFieldsBi dist = getDistance(coord);
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
            return true;
        }
        bool isAirY(int3 coord, DFieldBi xsize, DFieldBi zsize) {

            DFieldsBi dist = getDistance(coord);
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
            return true;
        }
        bool isAirZ(int3 coord, DFieldBi xsize, DFieldBi ysize) {

            DFieldsBi dist = getDistance(coord);
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
            return true;
        }

        DFieldsBi _processCellInner(ChunkData data,
                                    const int3 cellOffset,
                                    DFieldsBi fields,
                                    const int order)
        {
            auto view       = data.view;
            const cellCoord = (view.pos<<numRootBits)+cellOffset;
            const oct       = getOctree(cellOffset);
            const limits    = data.f[oct];

            bool goxup = true, goyup = true, gozup = true;
            bool goxdown = true, goydown = true, gozdown = true;

            void _expandX() {
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
            }
            void _expandY() {
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
            }
            void _expandZ() {
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

            while(goxup || goxdown || goyup || goydown || gozup || gozdown) {
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

            return fields;
        }

        auto maxDistance = DFieldsBi();
        auto volume      = 0L;

        DFieldsBi _processCell(ChunkData data, int3 cellOffset, DFieldsBi fields) {

            DFieldsBi bestFields;
            ulong bestVolume = 0;

            for(auto i=0; i<6; i++) {

                auto f = _processCellInner(data, cellOffset, fields, i);
                auto v = f.volume();

                if(v >= bestVolume) {
                    bestVolume = v;
                    bestFields = f;
                }
            }

            const oct = getOctree(cellOffset);
            data.view.setCellDistance(oct, bestFields);

            maxDistance = maxDistance.max(bestFields);

            return bestFields;
        }

        foreach(k,v; chunkMap) {

            auto view = v.view;
            if(!view.isAir) {

                DFieldsBi prevz = DFieldsBi();

                for(int z=0; z<size; z++) {

                    DFieldsBi prevy = prevz;

                    for(int y=0; y<size; y++) {

                        DFieldsBi prev = prevy;

                        for(int x=0; x<size; x++) {
                            auto p = int3(x,y,z);

                            if(view.isAirCell(getOctree(p))) {

                                prev    = _processCell(v, p, prev);
                                volume += prev.volume();

                                if(prev.x.up==0) prev = DFieldsBi(); else prev.x.up--;

                            } else {
                                prev = DFieldsBi();
                            }

                            if(x==0) {
                                prevy = prev;
                                if(prevy.y.up==0) prevy = DFieldsBi(); else prevy.y.up--;
                            }
                        }

                        if(y==0) {
                            prevz = prevy;
                            if(prevz.z.up==0) prevz = DFieldsBi(); else prevz.z.up--;
                        }
                    }
                }
            }
        }
        writefln("\tmaxDistance = %s", maxDistance);
        writefln("\tVolume      = %000,s", volume);
    }
}
