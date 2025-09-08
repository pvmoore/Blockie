#language slang 2026

import blockie;
import m3;

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

    float dist    = marchOut.distance;
    float3 hitPos = getHitPos(ubo, dataIn, pixel);

    float3 normal = calculateNormal(ubo, dataIn, pixel, hitPos);

    float ao = 1;
    float3 diffuse = ao * float3(0.352, 0.367, 0.363);

    if(true) {
        float4 t    = textureSampler.Sample((hitPos.xz+hitPos.y)/100.0f);
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
        //vec4 colour = float4(applyFog(diffuse.rgb, dist), diffuse.a);
        //vec4 colour = float4(applyFogWithSunScattering(diffuse.rgb, dist, rayDir, sunDir), diffuse.a);
        float4 colour = float4(applyGroundFog(diffuse.rgb, dist, ubo.cameraPos, rayDir), 1);
    #else
        // blend diffuse and sky based on distance from camera
        float fade = clamp(exp(8*(dist/15000)) / 120, 0.0, 1.0);
        float3 sky = vec3(0.345098,0.466667,0.560784);
        float4 colour = vec4(mix(diffuse.rgb, sky, fade), 1);
    #endif

    imageOut.Store(pixel, colour);
}

