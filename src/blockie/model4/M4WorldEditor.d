module blockie.model4.M4WorldEditor;

import blockie.all;

final class M4WorldEditor : WorldEditor {
private:
    World world;
    Model model;
    ChunkStorage storage;
    Chunk[] chunks;
    M4ChunkEditView[chunkcoords] chunkViews;
    StopWatch watch;
    uint numVoxelsEdited;
public:
    this(World world, Model model) {
        this.world   = world;
        this.model   = model;
        this.storage = new ChunkStorage(world, model);
    }
    void destroy() {
        storage.destroy();
    }
    void startTransaction() {
        writefln("WorldEditor: Start transaction");
        watch.start();
    }
    void commitTransaction() {
        writefln("WorldEditor: Commit transaction");
        writefln("WorldEditor: Processing %s chunk edits", chunkViews.length); flushConsole();
        foreach(v; chunkViews.values) {
            v.commitTransaction();
        }
        watch.stop();
        writefln("WorldEditor: Chunk updates took (%.2f seconds)", watch.peek().total!"nsecs"*1e-09);

        new ChunkDistanceFields(storage, chunks)
            .generate();

        new CellDistanceFieldsDirectional(chunks, model)
            .generate();

        calcUniqDistances();

        writefln("WorldEditor: Saving chunks"); flushConsole();
        foreach(c; chunks) {
            getEvents().fire(EventMsg(EventID.CHUNK_EDITED, c));
        }

        writefln("WorldEditor: Finished"); flushConsole();
    }
    /// Sets a single voxel
    void setVoxel(worldcoords wpos, ubyte value) {
        chunkcoords cpos = wpos >> CHUNK_SIZE_SHR;

        auto view = getChunkView(cpos);

        uint3 offset = cast(uint3)(wpos - (cpos<<CHUNK_SIZE_SHR));
        view.setVoxel(offset, value);
        numVoxelsEdited++;
    }
    /// Sets N voxel block
    void setVoxelBlock(worldcoords wpos, uint size, ubyte value) {
        assert(size <= 1024);

        for(uint z=0; z<size; z++) {
            for(uint y=0; y<size; y++) {
                for(uint x=0; x<size; x++) {
                    setVoxel(wpos+int3(x,y,z), value);
                }
            }
        }
    }
    /// solid rectangle
    void rectangle(worldcoords min, worldcoords max, ubyte value) {
        for(int z=min.z; z<=max.z; z++) {
            for(int y=min.y; y<=max.y; y++) {
                for(int x=min.x; x<=max.x; x++) {
                    setVoxel(worldcoords(x,y,z), value);
                }
            }
        }
    }
    /// hollow rectangle
    void rectangle(worldcoords min, worldcoords max, uint thickness, ubyte value) {
        int t = thickness-1;
        /// x
        rectangle(worldcoords(min.x,   min.y, min.z),
        worldcoords(min.x+t, max.y, max.z), value);
        rectangle(worldcoords(max.x-t, min.y, min.z),
        worldcoords(max.x,   max.y, max.z), value);
        /// y
        rectangle(worldcoords(min.x, min.y,   min.z),
        worldcoords(max.x, min.y+t, max.z), value);
        rectangle(worldcoords(min.x, max.y-t, min.z),
        worldcoords(max.x, max.y,   max.z), value);
        /// z
        rectangle(worldcoords(min.x, min.y, min.z),
        worldcoords(max.x, max.y, min.z+t), value);
        rectangle(worldcoords(min.x, min.y, max.z-t),
        worldcoords(max.x, max.y, max.z), value);
    }
    /// Solid sphere
    void sphere(worldcoords centre, uint minRadius, uint maxRadius, ubyte value) {
        float3 c = centre.to!float;
        for(int z=centre.z-maxRadius; z<centre.z+maxRadius; z++)
            for(int y=centre.y-maxRadius; y<centre.y+maxRadius; y++)
                for(int x=centre.x-maxRadius; x<centre.x+maxRadius; x++) {

                    float dist = distance(c, vec3(x,y,z));
                    if(dist>=minRadius && dist<=maxRadius) {
                        setVoxel(worldcoords(x,y,z), value);
                    }
                }
    }
    /// solid cylinder
    void cylinder(worldcoords start, worldcoords end, uint radius, ubyte value) {
        assert(false, "implement me");
    }
private:
    M4ChunkEditView getChunkView(chunkcoords coords) {
        M4ChunkEditView* ptr = coords in chunkViews;
        if(ptr) return *ptr;

        M4Chunk chunk        = cast(M4Chunk)storage.blockingGet(coords);
        M4ChunkEditView view = new M4ChunkEditView;
        view.beginTransaction(chunk);

        chunks ~= chunk;
        chunkViews[chunk.pos] = view;

        log("WorldEditor: new ChunkEditView %s", view); flushLog();
        return view;
    }
    void calcUniqDistances() {
        writefln("# chunks = %s", chunks.length);

        uint[M4Distance] uniq;
        uint totalCells = 0;

        foreach(ch; chunks) {
            auto c4 = cast(M4Chunk)ch;
            if(c4.root().isCells) {
                foreach(c; c4.root().cells) {
                    uniq[c.distance]++;
                    totalCells++;
                }
            }
        }
        writefln("\t#Cells = %s", totalCells);
        writefln("\t#uniq  = %s", uniq.length);
    }
}