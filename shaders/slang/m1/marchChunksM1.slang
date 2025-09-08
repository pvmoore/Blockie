#language slang 2026
implementing m1;

import blockie;

static const uint CELL_SIZE = CHUNK_SIZE >> 4;  // 64

[ForceInline] bool isAirChunk(Flags flags) { return CHUNK_FLAG(flags)==1; }
[ForceInline] uint3 airChunkDistanceField(Flags flags) { return uint3(CHUNK_DISTANCE_X(flags), CHUNK_DISTANCE_Y(flags), CHUNK_DISTANCE_Z(flags)); }
[ForceInline] float3 airCellDistanceField(uint v) { return float3(v & 31u, (v>>5) & 31u, (v>>10) & 31u); }

public Voxel march(const ChunksBuffer chunkDataIn, const VoxelsBuffer voxelsIn, const UBO ubo, const Ray ray, inout Position pos) {
    Voxel voxel = {};

    float distance = 0;
    uint voxels    = chunkDataIn[pos.chunk] / 4;
    Flags flags    = Flags(voxelsIn[voxels], voxelsIn[voxels+1]);

    // Assume:
    //      1) pos.chunk will always start with a valid chunk

    do{
        float dist;

        // March the current Chunk

        if(isAirChunk(flags)) {
            dist = getMinDistToEdge8BitsBiDirectional(ubo, ray, pos, airChunkDistanceField(flags), CHUNK_SIZE);
        } else {

            // March the Cell 
            if(!getAirVoxel(voxelsIn, pos, voxel, distance, voxels * 4)) break;

            const bool isRoot = (voxel.size == CELL_SIZE);

            if(isRoot) {
                uint dfield      = getUshort(voxelsIn, 0, ((voxels*4+DFIELD_OFFSET)>>1) + voxel.oct);
                float3 distances = airCellDistanceField(dfield);
                dist = getMinDistToEdgeUniDirectional(ubo, ray, pos, distances, CELL_SIZE);
            } else {
                dist = getMinDistToEdge(ubo, ray, pos, voxel.size);
            }
        }

        skipLOD(distance, dist);

        distance += dist;

        bool chunkChanged = pos.update(ubo, ray.direction*dist);

        if(chunkChanged) {
            if(pos.chunk==-1) {
                // We ran out of scenery
                voxel.value = 0;
                break;
            }
            voxels = chunkDataIn[pos.chunk] / 4;
            flags  = Flags(voxelsIn[voxels], voxelsIn[voxels+1]);
        }
	}while(distance<MAX_DISTANCE);

	voxel.distance = distance;
	return voxel;
}
