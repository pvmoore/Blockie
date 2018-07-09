#ifndef BBOX_C
#define BBOX_C

inline bool intersect(const BBox* bb,
                      const float3 rayPos,
                      const float3 rayInvDir,
                      float* min,
                      float* max)
{
	float3 tNearV = (bb->bounds[0]-rayPos) * rayInvDir;
    float3 tFarV  = (bb->bounds[1]-rayPos) * rayInvDir;
    float3 tNear  = fmin(tNearV, tFarV);
    float3 tFar   = fmax(tNearV, tFarV);

    *min = max_fff(tNear.x, tNear.y, tNear.z);
    *max = min_fff(tFar.x, tFar.y, tFar.z);

	return *max >= fmax(*min, 0);
}

#endif  // BBOX_C