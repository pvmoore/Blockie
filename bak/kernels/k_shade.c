
/**
 *   0
 * 3 d 1
 *   2
 */
float3 calculateNormal(
    const global float* inPositions,
    uint index,
    ShadeConstants c)
{
    const int U  = index-c.width;
    const int L  = index-1;
    const int P  = index;
    const int R  = index+1;
    const int D  = index+c.width;

    const float3 up    = vload3(U, inPositions);
    const float3 left  = vload3(L, inPositions);
    const float3 pos   = vload3(P, inPositions);
    const float3 right = vload3(R, inPositions);
    const float3 down  = vload3(D, inPositions);

    const float3 n1 = cross(up-pos, left-pos);
    const float3 n2 = cross(down-pos, right-pos);

    return normalize(n1+n2);
}

float4 getDiffuseColour(
    const global uchar* inVoxels,
    const global float* inPositions,
    uint index,
    ShadeConstants c)
{
    const float3 hitPos   = vload3(index, inPositions);
    const float3 lightPos = c.sunPos;
    const float3 normal   = calculateNormal(inPositions, index, c);
    const float3 toLight  = normalize(lightPos-hitPos);

    const float NdotL      = dot(normal, toLight);
    const float brightness = fmax(NdotL, 0);

    float4 pixel = getDiffuse(inVoxels[index]);

    return (pixel*0.70f) + (pixel*0.30f * brightness);
}

/**
 *  Take depth data and set image colours.
 *
 * x,y origin is at top-left.
 */
kernel void Shade(
    ShadeConstants c,                           // 0
    const global uchar* restrict inVoxels,      // 1
    const global float* restrict inPositions,   // 2
    write_only image2d_t image)                 // 3
{
    int x      = get_global_id(0);
    int y      = get_global_id(1);
    int lx     = get_local_id(0);
    int ly     = get_local_id(1);
    uint index = x+y*c.width;

    if(x>=0 && x<16 && y==0) {
        //printf("[%u,%u] %u", x,y, inVoxels[index]);
    }

    float4 colour = inVoxels[index] == 0
        ? (float4)(0,0,0,1)
        : getDiffuseColour(inVoxels, inPositions, index, c);

    write_imagef(image, (int2)(x,y), colour);
}
