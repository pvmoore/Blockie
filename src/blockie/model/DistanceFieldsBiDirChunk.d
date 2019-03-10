module blockie.model.DistanceFieldsBiDirChunk;

import blockie.all;
import std.algorithm.searching : minElement, maxElement;
import std.algorithm.iteration : fold;

final class DistanceFieldsBiDirChunk {
private:
    const int RADIUS = 20;
    ChunkStorage storage;
    Model model;
    StopWatch watch;
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

        writefln("\nGenerating air chunks ...");
        writefln("\tmin          = %s", chunkMin);
        writefln("\tmax          = %s", chunkMax);
        writefln("\tsize         = %s", gridSize);
        writefln("\tMAX          = %s", MAX);
        writefln("\tChunks in    = %s", views.length);
        flushConsole();

        watch.start();

        calculateInitialDistances();
        processVolumes();

        watch.stop();

        writefln("\tChunk grid   = %s chunks", map.length);

        writefln("\tTook (%.2f seconds)", watch.peek().total!"nsecs"*1e-09);
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

        DFieldsBi process(int3 chunkPos, int index, DFieldBi xstart) {
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

                        dist = process(pos, index, xstart);

                        xstart = DFieldBi(max(1, dist.x.up-1), max(1, dist.x.down));
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
    void processVolumes() {
        writefln("\tProcessing volumes"); flushConsole();

        auto maxDistance = DFieldsBi();
        const int X      = 1;
        const int Y      = gridSize.x;
        const int Z      = gridSize.x * gridSize.y;

        DFieldsBi getDistance(int index) {
            expect(index>=0 && index<distances.length);
            return distances[index];
        }

        bool isAirX(int index, DFieldBi ysize, DFieldBi zsize) {

            auto dist = getDistance(index);

            if(!dist.y.canContain(ysize) ||
               !dist.z.canContain(zsize)) return false;

            int i = index;
            for(int y=1; y<=ysize.up; y++) {
                i += Y;
                if(!getDistance(i).z.canContain(zsize)) return false;
            }
            i = index;
            for(int y=1; y<=ysize.down; y++) {
                i -= Y;
                if(!getDistance(i).z.canContain(zsize)) return false;
            }
            i = index;
            for(int z=1; z<=zsize.up; z++) {
                i += Z;
                if(!getDistance(i).y.canContain(ysize)) return false;
            }
            i = index;
            for(int z=1; z<=zsize.down; z++) {
                i -= Z;
                if(!getDistance(i).y.canContain(ysize)) return false;
            }
            return true;
        }
        bool isAirY(int index, DFieldBi xsize, DFieldBi zsize) {

            auto dist = getDistance(index);

            if(!dist.x.canContain(xsize) ||
               !dist.z.canContain(zsize)) return false;

            int i = index;
            for(int x=1; x<=xsize.up; x++) {
                i += X;
                if(!getDistance(i).z.canContain(zsize)) return false;
            }
            i = index;
            for(int x=1; x<=xsize.down; x++) {
                i -= X;
                if(!getDistance(i).z.canContain(zsize)) return false;
            }
            i = index;
            for(int z=1; z<=zsize.up; z++) {
                i += Z;
                if(!getDistance(i).x.canContain(xsize)) return false;
            }
            i = index;
            for(int z=1; z<=zsize.down; z++) {
                i -= Z;
                if(!getDistance(i).x.canContain(xsize)) return false;
            }
            return true;
        }
        bool isAirZ(int index, DFieldBi xsize, DFieldBi ysize) {

            auto dist = getDistance(index);

            if(!dist.x.canContain(xsize) ||
               !dist.y.canContain(ysize)) return false;

            int i = index;
            for(int x=1; x<=xsize.up; x++) {
                i += X;
                if(!getDistance(i).y.canContain(ysize)) return false;
            }
            i = index;
            for(int x=1; x<=xsize.down; x++) {
                i -= X;
                if(!getDistance(i).y.canContain(ysize)) return false;
            }
            i = index;
            for(int y=1; y<=ysize.up; y++) {
                i += Y;
                if(!getDistance(i).x.canContain(xsize)) return false;
            }
            i = index;
            for(int y=1; y<=ysize.down; y++) {
                i -= Y;
                if(!getDistance(i).x.canContain(xsize)) return false;
            }
            return true;
        }

        DFieldsBi processView(ChunkEditView view, int index, DFieldsBi fields) {
            bool goxup = true, goxdown = true,
                 goyup = true, goydown = true,
                 gozup = true, gozdown = true;

            auto limits = getDistance(index);

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

            view.setChunkDistance(fields);

            maxDistance = maxDistance.max(fields);

            return fields;
        }

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
                        prev = processView(view, index, prev);
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
    }
}