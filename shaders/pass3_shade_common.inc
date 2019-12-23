
/// Calculate the hit pos given a screen pixel
vec3 getHitPos(ivec2 pos) {
    uint i     = pos.x + (pos.y*SIZE.x);
    vec3 dir   = getRayDirForPixel(pos);
    float dist = dataIn[i].distance;
    return CAMERA_POS + (dir*dist);
}

vec3 calculateNormal(vec3 currentPos) {
    ivec2 i = pixel;
    ivec2 U = i+ivec2(0,-1);
    ivec2 L = i+ivec2(-1,0);
    ivec2 R = i+ivec2(1,0);
    ivec2 D = i+ivec2(0,1);

    const vec3 up    = getHitPos(U);
    const vec3 left  = getHitPos(L);
    const vec3 right = getHitPos(R);
    const vec3 down  = getHitPos(D);

    const vec3 n1 = cross(normalize(up-currentPos), normalize(left-currentPos));
    const vec3 n2 = cross(normalize(down-currentPos), normalize(right-currentPos));

    return normalize(n1+n2);
}

float getBrightness(const vec3 hitPos, const vec3 normal) {
    const vec3 lightPos = SUN_POS;
    const vec3 toLight  = normalize(lightPos-hitPos);
    const float NdotL   = dot(normal, toLight);
    return max(NdotL, 0);
}

vec3 applyFog(vec3  rgb,      // original color of the pixel
              float distance) // camera to point distance
{
    const float density = 0.00015;
    const float fogAmount = 1.0 - exp( -distance*density );
    const vec3  fogColor  = vec3(0.5,0.6,0.7);
    return mix(rgb, fogColor, fogAmount);
}
vec3 applyFogWithSunScattering(
    vec3  rgb,      // original color of the pixel
    float distance, // camera to point distance
    vec3  rayDir,   // camera to point vector
    vec3  sunDir)   // sun light direction
{
    const float density = 0.00015;
    float fogAmount = 1.0 - exp( -distance*density );
    float sunAmount = max( dot( rayDir, sunDir ), 0.0);
    vec3  fogColor  = mix( vec3(0.5,0.6,0.7), // bluish
                           vec3(1.0,0.9,0.7), // yellowish
                           pow(sunAmount,8.0) );
    return mix( rgb, fogColor, fogAmount );
}
vec3 applyGroundFog(
    vec3  rgb,      // original color of the pixel
    float distance, // camera to point distance
    vec3  rayOri,   // camera position
    vec3  rayDir)   // camera to point vector
{
    const float b = 0.0001;
    const float c = 1;
    const float fogAmount = c * exp(-rayOri.y*b) * (1.0-exp( -distance*rayDir.y*b ))/rayDir.y;
    const vec3  fogColor  = vec3(0.5,0.6,0.7);
    return mix( rgb, fogColor, fogAmount );
}