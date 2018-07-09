
// // distance
//	if(chunk) {
//	    subChunk = getSubChunk(&voxelData[chunk->voxelsOffset], upos);
//        #define subChunkIsAir    (isAirSubChunk(subChunk))
//        #define subChunkDistance (subChunk->indexes[0].v[2])
//        if(subChunkIsAir && subChunkDistance>1) {
//            ray.origin += (ray.direction *
//                          (subChunkDistance-1) * SUB_CHUNK_SIZE);
//            GET_CHUNK
//        }
//	}


kernel
void CalculateRays(
    global const float* restrict screenData, // 0 (middle, xdelta, ydelta)
    global float* restrict raysOut,			 // 1 (float3*width*height)
    const int width,					     // 2
    const int height)						 // 3
{
	int x  = get_global_id(0);
	int y  = get_global_id(1);
	int lx = get_local_id(0);
	int ly = get_local_id(1);

	local float3 data[3];
	if(lx==0 && ly==0) {
		data[0] = vload3(0, screenData);
		data[1] = vload3(1, screenData);
		data[2] = vload3(2, screenData);
	}
	barrier(CLK_LOCAL_MEM_FENCE);
	
	float3 middle = data[0];
	float3 xDelta = data[1];
	float3 yDelta = data[2];

	float x2 = x - width/2;
	float y2 = y - height/2;
    float3 r = normalize((middle + x2*xDelta) + y2*yDelta);

	vstore3(r, x + y*width, raysOut);
}

/// returns voxel normal (normalised)
/*inline static float3 getNormal(float3 hitPoint, float size) {
    float3 v   = rem_f3f(hitPoint, size) - (size/2.0f);
    float3 abs = fabs(v);
    float3 dir;
    dir.x = abs.x > abs.y && abs.x>abs.z;
    dir.y = !dir.x && abs.y>abs.z;
    dir.z = !dir.x && !dir.y;
    return dir * signum_f3(v);
}
inline float4 diffuse(float4 colour, Ray* ray, float size) {
    float3 hitPoint = ray->position;
    float3 normal   = getNormal(hitPoint, size);
    float3 toLight  = normalize(lightPos - hitPoint);

	float NdotL 	 = dot(normal, toLight);
	float brightness = fmax(NdotL, 0);
	return colour + (brightness * colour * 0.5f);
}
inline float4 setPixel(Voxel* voxel, bool inShadow, Ray* ray) {
    uchar value   = voxel->value;
    ushort size   = voxel->size;
	float4 colour = uchar_to_pixel[value];
	float brightness = 1.0f - (inShadow * 0.20f);

//	if(value>0) {
//	    colour = diffuse(colour, ray, size);
//	}

	return colour * brightness;
}
*/

/*
    if(voxel.value) {
        // We hit something.

        // reverse until we are back in air again
        ray.direction   *= -1;
        ray.invDirection = 1.0f/ray.direction;
        float dist = getMinDistToEdge(&ray, voxel.size)+0.1f;
        ray.position += ray.direction*dist;
        getChunk(&pos, ray.position);

        // Fire off a shadow ray
        ray.direction    = normalize(lightPos-ray.position);
        ray.invDirection = 1.0f/ray.direction;

        inShadow = march(&ray, &pos, FLT_MAX).value>0;
    }
    */