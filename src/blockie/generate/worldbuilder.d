module blockie.generate.worldbuilder;

import blockie.all;
import blockie.generate.all;

__gshared ulong maxChunkDistance;

final class WorldBuilder : WorldEditor {
private:
    M1ChunkEditView[chunkcoords] editingChunks;
    StopWatch watch;
    ulong numVoxelsEdited;
public:
    M1Chunk[] getChunks() {
        return editingChunks.values.map!(it=>it.chunk).array;
    }
    void destroy() {

    }
    void startTransaction() {
        watch.start();
    }
    void commitTransaction() {
        optimise();
        writefln("WorldEditor: Finished in %.2f seconds (%s voxels edited)",
            watch.peek().total!"nsecs"*1e-09, numVoxelsEdited);
    }
    void setVoxel(worldcoords pos, ubyte value) {
        int3 cp = pos >> CHUNK_SIZE_SHR;
        auto c = getChunk(cp);
        if(c) {
            setOctreeVoxel(c, value,
                pos.x-(cp.x<<CHUNK_SIZE_SHR),
                pos.y-(cp.y<<CHUNK_SIZE_SHR),
                pos.z-(cp.z<<CHUNK_SIZE_SHR));
        }
        numVoxelsEdited++;
    }
    void setVoxelBlock(worldcoords wpos, uint size, ubyte value) {
        assert(false, "implement me");
    }
    void rectangle(worldcoords min, worldcoords max, ubyte value) {
        for(int z=min.z; z<=max.z; z++)
        for(int y=min.y; y<=max.y; y++)
        for(int x=min.x; x<=max.x; x++) {
            setVoxel(worldcoords(x,y,z), value);
        }
    }
    void rectangle(worldcoords min, worldcoords max, uint thickness, ubyte value) {
        int t = thickness-1;
        // x
        rectangle(ivec3(min.x,   min.y, min.z),
                  ivec3(min.x+t, max.y, max.z), value);
        rectangle(ivec3(max.x-t, min.y, min.z),
                  ivec3(max.x,   max.y, max.z), value);
        // y
        rectangle(ivec3(min.x, min.y,   min.z),
                  ivec3(max.x, min.y+t, max.z), value);
        rectangle(ivec3(min.x, max.y-t, min.z),
                  ivec3(max.x, max.y,   max.z), value);
        // z
        rectangle(ivec3(min.x, min.y, min.z),
                  ivec3(max.x, max.y, min.z+t), value);
        rectangle(ivec3(min.x, min.y, max.z-t),
                  ivec3(max.x, max.y, max.z), value);
    }
    void sphere(worldcoords centre, uint minRadius, uint maxRadius, ubyte value) {
        vec3 c = centre.to!float;
        for(int z=centre.z-maxRadius; z<centre.z+maxRadius; z++)
        for(int y=centre.y-maxRadius; y<centre.y+maxRadius; y++)
        for(int x=centre.x-maxRadius; x<centre.x+maxRadius; x++) {

            float dist = distance(c, vec3(x,y,z));
            if(dist>=minRadius && dist<=maxRadius) {
                setVoxel(worldcoords(x,y,z), value);
            }
        }
    }
    void cylinder(worldcoords start, worldcoords end, uint radius, ubyte value) {
        assert(false, "implement me");
    }

    WorldBuilder setVoxel(ubyte v, int x, int y, int z) {
        int x2 = x >> CHUNK_SIZE_SHR;
        int y2 = y >> CHUNK_SIZE_SHR;
        int z2 = z >> CHUNK_SIZE_SHR;
        auto c = getChunk(chunkcoords(x2,y2,z2));
        if(c) {
            setOctreeVoxel(c, v,
                x-(x2<<CHUNK_SIZE_SHR),
                y-(y2<<CHUNK_SIZE_SHR),
                z-(z2<<CHUNK_SIZE_SHR));
        }
        return this;
    }
private:
    M1ChunkEditView getChunk(chunkcoords cp) {
        M1ChunkEditView* ptr = cp in editingChunks;
        if(ptr) return *ptr;

        M1Chunk chunk        = new M1Chunk(cp);
        M1ChunkEditView view = chunk.beginEdit();

        editingChunks[chunk.pos] = view;
        return view;
    }
    auto optimise() {
        log("Optimising chunks"); flushLog();
        M1ChunkEditView[] views = editingChunks.values;

        ulong count = views.map!(it=>it.voxelsLength)
                           .sum();
        foreach(i, v; views) {
            ulong pre = v.voxelsLength;
            v.chunk.endEdit(v);
            writefln("Optimised chunk %s %s / %s  %s --> %s (%.2f%%)", v.chunk.pos, i+1, views.length,
                pre, v.chunk.voxels.length, v.chunk.voxels.length*100.0 / pre);
        }
        ulong count2 = views.map!(it=>it.chunk.voxels.length)
                            .sum();
        log("Optimised chunks from %s bytes to %s bytes", count, count2);
        return this;
    }
}

