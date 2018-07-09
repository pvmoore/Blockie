

Voxel march(const Ray* ray,
            Position* pos,
            float maxDistance)
{
    Voxel voxel    = {0,0};
    float distance = 0;

    // march
	while(pos->chunk &&
	      distance<maxDistance &&
	      getAirVoxel(pos, &voxel))
    {
        // We are inside an air voxel.
        // Move to the edge
        float dist = getMinDistToEdge(ray, pos, voxel.size);
        // handle pathological case
        dist += (dist<0.0001f) * 1.2f;
        // plus a little bit for luck
        dist += 0.0025f;

        distance += dist;

        updatePosition(pos, ray->direction*dist);
	}
	return voxel;
}

const Ray generateRay(int x, int y, Constants constants) {
    float3 middle = constants.screenMiddle;
    float3 xDelta = constants.screenXDelta;
    float3 yDelta = constants.screenYDelta;
    float x2      = x - (float)constants.width/2.0;
    float y2      = y - (float)constants.height/2.0;

	Ray ray;
	ray.start        = constants.cameraOrigin;
	ray.direction    = normalize((middle + x2*xDelta) + y2*yDelta);
	ray.invDirection = 1.0f/ray.direction;
    return ray;
}

/**
 *
 * x,y origin is at top-left.
 */
kernel void March(
    const Constants constants,              // 0
    const global uchar* restrict voxelData, // 1
    const global uchar* restrict chunkData,	// 2
    global uchar* restrict outVoxels,       // 3
    global float* restrict outPositions)    // 4
{
    int x      = get_global_id(0);
    int y      = get_global_id(1);
    int lx     = get_local_id(0);
    int ly     = get_local_id(1);
    uint index = x+y*constants.width;

    //barrier(CLK_LOCAL_MEM_FENCE);
    if(x==0 && y==0) {

    }

    const Ray ray = generateRay(x,y,constants);

    // NB. This whole section is only here because the camera
    // starts outside the world. In the future this will
    // not be required and we can remove parts A and B.
//partA:
	// does ray intersect with the world at all?
	float minT, maxT;
	if(!intersect(&constants.worldBB,
	              ray.start,
	              ray.invDirection,
	              &minT,
	              &maxT))
    {
		outVoxels[index] = 0;
		return;
	}
	// minT 			 = distance to world entry (negative if camera is inside world box)
	// maxT - fabs(minT) = distance to world exit

	// if camera is outside the world box, move the camera to the entry point
	float3 rayToWorld = ray.start - constants.worldBB.bounds[0];
	int outsideWorld  = (minT>=0);
	float3 rayPos = outsideWorld ?
	    (rayToWorld + ray.direction * minT)
	    : ray.start;

    Position pos = {
        voxelData,  // voxelData
        chunkData,  // chunkData
        NULL,       // Chunk*
        (uint3)(constants.chunksX, // worldSizeInChunks
                constants.chunksY,
                constants.chunksZ),
        (uint3)(0), // upos
        rayPos      // fpos
    };

//partB:
    // ensure we are inside a chunk
	while(!pos.chunk && maxT > 0) {
		updatePosition(&pos, ray.direction*0.1f);
		maxT -= 0.5f; // this is weird
	}

//partC:
    Voxel voxel = march(&ray, &pos, FLT_MAX);

    outVoxels[index] = voxel.value;
    vstore3(pos.fpos, index, outPositions);
}


