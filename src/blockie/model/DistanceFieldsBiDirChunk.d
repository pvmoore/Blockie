module blockie.model.DistanceFieldsBiDirChunk;

import blockie.model;
import std.algorithm.searching : minElement, maxElement;
import std.algorithm.iteration : fold;

final class DistanceFieldsBiDirChunk {
private:
    const int RADIUS = 20;
    ChunkStorage storage;
    Model model;
    ChunkEditView[] views;
    ChunkEditView[] addedViews;
    ChunkEditView[chunkcoords] map;
    ChunkEditView fakeView;
    chunkcoords chunkMin, chunkMax, gridSize;
    int MAX;

    DFieldsBi[] distances;
public:
    ChunkEditView[] getAddedViews() { return addedViews; }

    this(ChunkStorage storage, ChunkEditView[] views, uint max) {
        this.storage   = storage;
        this.views     = views;
        this.model     = storage.model;
        this.fakeView  = new FakeEditView(false);

        this.chunkMin = views.map!(it=>it.pos)
                             .fold!((a,b)=>a.min(b))(chunkcoords(int.max));
        this.chunkMax = views.map!(it=>it.pos)
                             .fold!((a,b)=>a.max(b))(chunkcoords(int.min));

        chunkMin -= RADIUS;
        chunkMax += RADIUS;

        this.gridSize = chunkMax-chunkMin + 1;

        MAX = (chunkMax.max() - chunkMin.min())+1;
        if(MAX>max) MAX = max;

        /// store existing non-air chunks
        foreach(v; views) {
            map[v.pos] = v;
        }

        this.distances = new DFieldsBi[gridSize.hmul()];
    }
    auto generate() {
        if(views.length==0) return this;

        writefln("Generating air chunks {");
        writefln("\tmin          = %s", chunkMin);
        writefln("\tmax          = %s", chunkMax);
        writefln("\tsize         = %s", gridSize);
        writefln("\tMAX          = %s", MAX);
        writefln("\tChunks in    = %s", views.length);
        flushConsole();

        StopWatch totalTime;
        totalTime.start();

        StopWatch watch;
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

        writefln("\tChunk grid   = %s chunks", map.length);

        totalTime.stop();
        writefln("\tTotal time to generate air chunks ... (%.2f seconds)", totalTime.peek().total!"nsecs"*1e-09);
        writefln("}");
        return this;
    }
private:
    ChunkEditView getView(chunkcoords p) {
        auto ptr = p in map;
        if(ptr) return *ptr;

        if(p.anyLT(chunkMin) || p.anyGT(chunkMax)) return fakeView;


        Chunk c = storage.blockingGet(p);
        auto view = model.makeEditView();

        view.beginTransaction(c);

        addedViews ~= view;
        map[p] = view;

        return view;
    }
    bool isAir(int3 pos) {
        return getView(pos).isAir;
    }
    void calculateInitialDistances() {
        writefln("\tCalculating initial distances"); flushConsole();

        auto maxDistance = DFieldsBi();
        int numAirChunks;

        DFieldsBi _process(int3 chunkPos, int index, DFieldBi xstart) {
            DFieldsBi f;
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

                DFieldsBi dist;
                auto xstart = DFieldBi(1,1);

                for(auto x=chunkMin.x; x<=chunkMax.x; x++) {
                    auto pos  = int3(x,y,z);
                    auto view = getView(pos);
                    if(view.isAir) {
                        numAirChunks++;

                        //StopWatch w; w.start();
                        dist = _process(pos, index, xstart);
                        //w.stop();
                        //dbg("_process: %.2f ms (%s)", w.peek().total!"nsecs"*1e-06, map.length);

                        xstart = DFieldBi(maxOf(1, dist.x.up-1), maxOf(1, dist.x.down));
                    } else {
                        xstart = DFieldBi(1,1);
                    }
                    index++;
                }
            }
        }

        writefln("\tInitial max  = %s", maxDistance);
        writefln("\tnumAirChunks = %s", numAirChunks);
        flushConsole();
    }
    DFieldsBi _getDistance(int index) {
        expect(index>=0 && index<distances.length);
        return distances[index];
    }
    bool _isAirX(const int index, const DFieldBi ysize, const DFieldBi zsize) {

        const int Y = gridSize.x;
        const dist  = _getDistance(index);

        if(!dist.y.canContain(ysize) || !dist.z.canContain(zsize)) return false;

        int i = index;
        for(int y=1; y<=ysize.up; y++) {
            i += Y;
            if(!_getDistance(i).z.canContain(zsize)) return false;
        }
        i = index;
        for(int y=1; y<=ysize.down; y++) {
            i -= Y;
            if(!_getDistance(i).z.canContain(zsize)) return false;
        }
        return true;
    }
    bool _isAirY(const int index, const DFieldBi xsize, const DFieldBi zsize) {

        const int X = 1;
        const dist  = _getDistance(index);

        if(!dist.x.canContain(xsize) || !dist.z.canContain(zsize)) return false;

        int i = index;
        for(int x=1; x<=xsize.up; x++) {
            i += X;
            if(!_getDistance(i).z.canContain(zsize)) return false;
        }
        i = index;
        for(int x=1; x<=xsize.down; x++) {
            i -= X;
            if(!_getDistance(i).z.canContain(zsize)) return false;
        }
        return true;
    }
    bool _isAirZ(const int index, const DFieldBi xsize, const DFieldBi ysize) {

        const int X = 1;
        const dist  = _getDistance(index);

        if(!dist.x.canContain(xsize) || !dist.y.canContain(ysize)) return false;

        int i = index;
        for(int x=1; x<=xsize.up; x++) {
            i += X;
            if(!_getDistance(i).y.canContain(ysize)) return false;
        }
        i = index;
        for(int x=1; x<=xsize.down; x++) {
            i -= X;
            if(!_getDistance(i).y.canContain(ysize)) return false;
        }
        return true;
    }
    DFieldsBi processCellInner(ChunkEditView view,
                               const int index,
                               DFieldsBi fields,
                               const int order)
    {
        const int Y = gridSize.x;
        const int Z = gridSize.x * gridSize.y;

        bool goxup = true, goxdown = true,
             goyup = true, goydown = true,
             gozup = true, gozdown = true;

        const limits = _getDistance(index);

        void _expandX() {
            if(goxup) {
                if(fields.x.up < limits.x.up &&
                    _isAirX(index+(fields.x.up+1), fields.y, fields.z))
                {
                    fields.x.up++;
                }
                else goxup = false;
            }
            if(goxdown) {
                if(fields.x.down < limits.x.down &&
                    _isAirX(index-(fields.x.down+1), fields.y, fields.z))
                {
                    fields.x.down++;
                }
                else goxdown = false;
            }
        }
        void _expandY() {
            if(goyup) {
                if(fields.y.up < limits.y.up &&
                    _isAirY(index+(fields.y.up+1)*Y, fields.x, fields.z))
                {
                    fields.y.up++;
                }
                else goyup = false;
            }
            if(goydown) {
                if(fields.y.down < limits.y.down &&
                    _isAirY(index-(fields.y.down+1)*Y, fields.x, fields.z))
                {
                    fields.y.down++;
                }
                else goydown = false;
            }
        }
        void _expandZ() {
            if(gozup) {
                if(fields.z.up < limits.z.up &&
                    _isAirZ(index+(fields.z.up+1)*Z, fields.x, fields.y))
                {
                    fields.z.up++;
                }
                else gozup = false;
            }
            if(gozdown) {
                if(fields.z.down < limits.z.down &&
                    _isAirZ(index-(fields.z.down+1)*Z, fields.x, fields.y))
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
    DFieldsBi _processCell(ChunkEditView view, const int index, const DFieldsBi fields) {

        DFieldsBi bestFields;
        ulong bestVolume = 0;

        for(auto i=0; i<6; i++) {

            auto f   = processCellInner(view, index, fields, i);
            auto vol = f.volume();

            if(vol >= bestVolume) {
                bestVolume = vol;
                bestFields = f;
            }
        }

        view.setChunkDistance(bestFields);

        return bestFields;
    }
    void processVolumes() {
        writefln("\tProcessing volumes"); flushConsole();

        auto maxDistance = DFieldsBi();
        ulong volume     = 0;

        /// Traverse all chunks including margin.
        int index  = 0;
        auto prevz = DFieldsBi();

        for(auto z=chunkMin.z; z<=chunkMax.z; z++) {

            auto prevy = prevz;

            for(auto y=chunkMin.y; y<=chunkMax.y; y++) {

                auto prev = prevy;

                for(auto x=chunkMin.x; x<=chunkMax.x; x++) {
                    auto view = getView(int3(x,y,z));

                    if(view.isAir) {

                        prev = _processCell(view, index, prev);

                        maxDistance = maxDistance.max(prev);

                        volume += prev.volume();

                        if(prev.x.up==0) {
                            prev = DFieldsBi();
                        } else {
                            prev.x.up--;
                        }
                    } else {
                        prev = DFieldsBi();
                    }
                    if(x==chunkMin.x) {
                        prevy = prev;
                        if(prevy.y.up==0) prevy = DFieldsBi(); else prevy.y.up--;
                    }
                    index++;
                }
                if(y==chunkMin.y) {
                    prevz = prevy;
                    if(prevz.z.up==0) prevz = DFieldsBi(); else prevz.z.up--;
                }
            }
        }
        writefln("\tmaxDistance = %s", maxDistance);
        writefln("\tVolume      = %000,s", volume);
    }
}
