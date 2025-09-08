#language slang 2026
implementing blockie;

public struct Position {
    public uint3 upos; // current worldcoords position relative to BB min (truncated uint)
    public float3 fpos;  // actual current worldcoords position (float)
    public int chunk;  // offset into chunkDataIn

    public __init(const UBO ubo, float3 fpos) {
        this.fpos  = fpos;
        this.chunk = -1;
        update(ubo, float3(0));
    } 

    [mutating]
    /// Return true if chunk changes
    public bool update(const UBO ubo, float3 add) {

        fpos += add;
        upos  = int3(floor(fpos-ubo.worldBBMin));

        uint3 xyz = upos >> CHUNK_SIZE_SHR;

        bool outOfBounds = any(xyz >= ubo.worldChunksXYZ);

        int prevChunk = chunk;
        chunk = outOfBounds ? -1 : int(dot(xyz, ubo.chunksMul()));
        return chunk != prevChunk;
    }
}

