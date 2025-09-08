#language slang 2026
implementing blockie;

public Ray generateRay(const UBO ubo, float2 pixel) {
    return Ray(ubo.cameraPos, getRayDirForPixel(ubo, pixel));
}

public float3 getRayDirForPixel(const UBO ubo, float2 pixel) {
    float2 mid = pixel - float2(ubo.size)/2.0f;
    return normalize((ubo.screenMiddle + mid.x*ubo.screenXDelta) + mid.y*ubo.screenYDelta);
}
