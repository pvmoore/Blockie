module blockie.generate.worldbuilder;

import blockie.all;
import blockie.generate.all;

__gshared ulong maxChunkDistance;

final class WorldBuilder {
private:
    ChunkEditView[ivec3] editingChunks;
public:
    Chunk[] getChunks() {
        return editingChunks.values.map!(it=>it.chunk).array;
    }
    auto commit() {
        optimise();
        return this;
    }
    auto setVoxel(ubyte v, ivec3 pos) {
        setVoxel(v, pos.x, pos.y, pos.z);
        return this;
    }
    auto setVoxel(ubyte v, int x, int y, int z) {
        int x2 = x >> CHUNK_SIZE_SHR;
        int y2 = y >> CHUNK_SIZE_SHR;
        int z2 = z >> CHUNK_SIZE_SHR;
        auto c = getChunk(ivec3(x2,y2,z2));
        if(c) {
            setOctreeVoxel(c, v,
                x-(x2<<CHUNK_SIZE_SHR),
                y-(y2<<CHUNK_SIZE_SHR),
                z-(z2<<CHUNK_SIZE_SHR));
        }
        return this;
    }
private:
    ChunkEditView getChunk(ivec3 cp) {
        ChunkEditView* ptr = cp in editingChunks;
        if(ptr) return *ptr;

        Chunk chunk        = Chunk.airChunk(cp);
        ChunkEditView view = chunk.beginEdit();

        editingChunks[chunk.pos] = view;
        return view;
    }
    auto optimise() {
        ChunkEditView[] views = editingChunks.values;
        ulong count = views.map!(it=>it.voxelsLength)
                           .sum();
        foreach(i, v; views) {
            //writefln("Optimising chunk %s %s / %s", v.chunk.pos, i+1, views.length); flushStdErrOut();
            v.chunk.endEdit(v);
        }
        ulong count2 = views.map!(it=>it.chunk.voxels.length)
                            .sum();
        log("Optimised chunks from %s bytes to %s bytes", count, count2);
        return this;
    }
}

