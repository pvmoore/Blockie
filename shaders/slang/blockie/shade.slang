#language slang 2026
implementing blockie;

/// Calculate the hit pos given a screen pixel
public float3 getHitPos(const UBO ubo, const MarchInputBuffer dataIn, int2 pos) {

    // handle out of bounds
    pos = clamp(pos, int2(0), int2(ubo.size)-int2(1));

    uint i     = pos.x + (pos.y*ubo.size.x);
    float3 dir = getRayDirForPixel(ubo, pos);
    float dist = dataIn[i].distance;
    return ubo.cameraPos + (dir*dist);
}

public float3 calculateNormal(const UBO ubo, const MarchInputBuffer dataIn, int2 pixel, float3 currentPos) {
    const int2 i = pixel;
    const int2 U = i+int2(0,-1);
    const int2 L = i+int2(-1,0);
    const int2 R = i+int2(1,0);
    const int2 D = i+int2(0,1);

    const float3 up    = getHitPos(ubo, dataIn, U);
    const float3 left  = getHitPos(ubo, dataIn, L);
    const float3 right = getHitPos(ubo, dataIn, R);
    const float3 down  = getHitPos(ubo, dataIn, D);

    const float3 n1 = cross(normalize(up-currentPos), normalize(left-currentPos));
    const float3 n2 = cross(normalize(down-currentPos), normalize(right-currentPos));

    return normalize(n1+n2);
}

public float getBrightness(const UBO ubo, const float3 hitPos, const float3 normal) {
    const float3 lightPos = ubo.sunPos;
    const float3 toLight  = normalize(lightPos-hitPos);
    const float NdotL     = dot(normal, toLight);
    return max(NdotL, 0);
}

public float3 applyGroundFog(float3  rgb,        // original color of the pixel
                             float distance,     // camera to point distance
                             float3  rayOri,     // camera position
                             float3  rayDir)     // camera to point vector
{
    const float b = 0.0001;
    const float c = 1;
    const float fogAmount = c * exp(-rayOri.y*b) * (1.0-exp( -distance*rayDir.y*b ))/rayDir.y;
    const float3  fogColor  = float3(0.5,0.6,0.7);
    return lerp(rgb, fogColor, fogAmount);
}
