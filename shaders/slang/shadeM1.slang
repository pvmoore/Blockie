#language slang 2026

import blockie;
import m1;

static const uint V_EARTH1 = 10;
static const uint V_ROCK1  = 11;
static const uint V_GRASS1 = 12;

[[vk::binding(2, 0)]] MarchInputBuffer dataIn; 
[[vk::binding(3, 0)]] ConstantBuffer<UBO, Std140DataLayout> ubo; 
[[vk::binding(4, 0)]] [format("rgba8")] WTexture2D<float4> imageOut; 
[[vk::binding(5, 0)]] Sampler2D textureSampler;
[[vk::binding(6, 0)]] SamplerCube skyboxSampler;

[shader("compute")]
[numthreads(8,8,1)]
void main(uint3 threadId : SV_DispatchThreadID) {
    int2 pixel      = int2(threadId.xy);
    uint imageIndex = threadId.x + (threadId.y*ubo.size.x);

    let marchOut   = dataIn[imageIndex];
    uint voxelInfo = marchOut.voxel;
    uint voxel     = voxelInfo & 0xffu;  

    if(voxel==0) {
        // Skybox
        Ray ray       = generateRay(ubo, pixel);
        float4 skybox = skyboxSampler.Sample(ray.direction); 

        imageOut.Store(pixel, skybox);
        return;
    }

    float dist  = dataIn[imageIndex].distance;
    float3 hitPos = getHitPos(ubo, dataIn, pixel);
    float3 normal = calculateNormal(ubo, dataIn, pixel, hitPos);

    float3 diffuse = getDiffuseColour(voxel);

    if(true) {//} || voxel==V_ROCK1 || voxel==V_GRASS1 || voxel==V_EARTH1) {
        float4 t  = textureSampler.Sample((hitPos.xz+hitPos.y)/100);
        diffuse.xyz = diffuse.xyz*0.25 + t.xyz;
    }

    // diffuse lighting
    diffuse = lerp(diffuse*0.25, diffuse, getBrightness(ubo, hitPos, normal));

    // noise
    diffuse += clamp(40/(dist+0.1), 0.0, 0.2)*snoise(hitPos*5);

    #define FOG 1
    #if FOG
        float3 rayDir = normalize(hitPos-ubo.cameraPos);
        float3 sunDir = normalize(ubo.sunPos-ubo.cameraPos);
        //const vec4 colour = vec4(applyFog(diffuse.rgb, dist), diffuse.a);
        //const vec4 colour = vec4(applyFogWithSunScattering(diffuse.rgb, dist, rayDir, sunDir), diffuse.a);
        float4 colour = float4(applyGroundFog(diffuse.rgb, dist, ubo.cameraPos, rayDir), 1);
    #else
        // blend diffuse and sky based on distance from camera
        float fade    = clamp(exp(8*(dist/15000)) / 120, 0.0, 1.0);
        float3 sky    = float3(0.345098,0.466667,0.560784);
        float4 colour = float4(mix(diffuse.rgb, sky, fade), 1);
    #endif

    imageOut.Store(pixel, colour);
}

float3 getDiffuse(uint voxel) {
    return uint_to_pixel[voxel];
}

float3 getDiffuseColour(uint voxel) {
    return getDiffuse(voxel);
}

// FIXME - This would probably be faster if it was in a storage buffer
static const float3[] uint_to_pixel = {
    // volumetric
	float3(0,0, 0.25),	 // [0] V_AIR (space)
	float3(0.156863,0.290196,0.341176),         // [1] water
    float3(0.7,0.7,0.7),   // [2] smoke
    // reserved
    float3(0,0,0),         // [3] reserved
    float3(0,0,0),         // [4] reserved
    float3(0,0,0),         // [5] reserved
    float3(0,0,0),         // [6] reserved
    float3(0,0,0),         // [7] reserved
    float3(0,0,0),         // [8] reserved
    float3(0,0,0),         // [9] reserved

    // single voxels
    float3(0.5059, 0.3686, 0.2627)*0.7,	// [10] V_EARTH1
    float3(0.352, 0.367, 0.363),          // [11] V_ROCK1
    float3(0.2, 0.7,  0.2),	            // [12] V_GRASS1
    float3(1.0, 1.0,  1.0),               // [13] V_SNOW
    float3(1.0, 0.8,  0.5)                // [14] V_SAND
};
