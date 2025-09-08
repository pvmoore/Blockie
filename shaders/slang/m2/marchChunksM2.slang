#language slang 2026
implementing m2;

import blockie;

// Note: This file is identical to marchChunksM3.slang apart from the CELL_SIZE

static const uint CELL_SIZE = CHUNK_SIZE >> 4;  // 64

[ForceInline] bool isAirChunk(Flags flags) { return CHUNK_FLAG(flags)==0; }
[ForceInline] uint3 getChunkDistanceField(Flags f) { return uint3(CHUNK_DISTANCE_X(f), CHUNK_DISTANCE_Y(f), CHUNK_DISTANCE_Z(f)); }

/// Unpacks x,y,z from 2nd,3rd and 4th ubyte of _val_
[ForceInline] uint3 getCellDistanceField(uint val) {
    return uint3(unpackUnorm4x8ToFloat(val).yzw * 255);
}

public Voxel march(const ChunksBuffer chunkDataIn, const VoxelsBuffer voxelsIn, const UBO ubo, const Ray ray, inout Position pos) {
    Voxel voxel = {};

    float distance = 0;
    uint voxels    = chunkDataIn[pos.chunk] / 4;
    Flags flags    = Flags(voxelsIn[voxels], voxelsIn[voxels+1]);

    // Assume:
    //      1) pos.chunk will always start with a valid chunk

    while(true) {
        float dist;

        // March the current Chunk

        if(isAirChunk(flags)) {
            dist = getMinDistToEdge8BitsBiDirectional(ubo, ray, pos, getChunkDistanceField(flags), CHUNK_SIZE);
        } else {

            // March the Cell 
            if(!getAirVoxel(voxelsIn, pos, voxel, distance, voxels)) {
                /// We have hit something
                break;
            }

            /// We are inside an air voxel of some size

            bool isCell = (voxel.size == CELL_SIZE);

            if(isCell) {
                uint cell       = voxelsIn[voxels + 2 + voxel.oct];
                uint3 distances = getCellDistanceField(cell);

                // 4 bit per dir per axis cell distances
                // uint3 distances = uint3((cell>>8) & 0xff,   // up,down x
                //                         (cell>>16) & 0xff,  // up,down y
                //                         (cell>>24) & 0xff); // up,down z

                dist = getMinDistToEdge4BitsBiDirectional(ubo, ray, pos, distances, CELL_SIZE);
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
	}

	voxel.distance = distance;
	return voxel;
}



