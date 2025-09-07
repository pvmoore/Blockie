module blockie.model.WorldEditor;

import blockie.model;

abstract class WorldEditor {
protected:
    World world;
    Model model;
    ChunkStorage storage;
    ChunkEditView[] views;
    ChunkEditView[chunkcoords] viewMap;
    StopWatch watch;
    uint numVoxelsEdited;

    ChunkEditView getChunkView(chunkcoords coords) {
        ChunkEditView* ptr = coords in viewMap;
        if(ptr) return *ptr;

        Chunk chunk        = storage.blockingGet(coords);
        ChunkEditView view = model.makeEditView();
        view.beginTransaction(chunk);

        views ~= view;
        viewMap[chunk.pos] = view;

        return view;
    }
    abstract void generateDistances();
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
        writefln("WorldEditor: Starting transaction");
        watch.start();
    }
    void commitTransaction() {
        writefln("WorldEditor: Committing %s chunk edits ...", viewMap.length); flushConsole();

        foreach(v; views) {
            v.voxelEditsCompleted();
        }

        generateDistances();

        writefln("\nWorldEditor: Committing transaction (%s views) ...\n", views.length); flushConsole();
        foreach(v; views) {
            v.commitTransaction();
        }

        writefln("\tFiring chunk update events");
        foreach(v; views) {
            getEvents().fire(EventMsg(EventID.CHUNK_EDITED, v.getChunk()));
        }

        watch.stop();
        writefln("\nWorldEditor: Transaction took %.2f seconds", watch.peek().total!"nsecs"*1e-09);
        flushConsole();
    }
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

                    float dist = c.distanceTo(float3(x,y,z));
                    if(dist>=minRadius && dist<=maxRadius) {
                        setVoxel(worldcoords(x,y,z), value);
                    }
                }
    }
    /// solid cylinder
    void cylinder(worldcoords start, worldcoords end, uint radius, ubyte value) {
        assert(false, "implement me");
    }
}
