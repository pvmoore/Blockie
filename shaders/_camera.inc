
#line 1000

vec3 getRayDirForPixel(ivec2 p) {
    vec2 mid = vec2(p) - vec2(ubo_SIZE)/2.0f;
    return normalize((ubo_SCREEN_MIDDLE + mid.x*ubo_SCREEN_XDELTA) + mid.y*ubo_SCREEN_YDELTA);
}
Ray generateRay() {
    Ray ray;
    ray.start        = ubo_CAMERA_POS;
    ray.direction    = getRayDirForPixel(pixel);
    ray.invDirection = 1.0f/ray.direction;
    return ray;
}

/*
Ray getRay(vec2 pixel) {
    /// Calculate pixel position in camera space
    vec2 pos = 2*((pixel+0.5)/SIZE);
    pos.x -= 1;
    pos.y  = 1-pos.y;
    pos *= (ASPECT_RATIO * TANFOV2);

    /// Convert direction vector from camera space to world space
    vec3 P  = vec3(pos, -1);
    vec3 OP = (INVVIEW * vec4(P, 0)).xyz;

    Ray r;
    r.start        = CAMERA_ORIGIN;
    r.direction    = normalize(OP);
    r.invDirection = 1.0f/r.direction;
    return r;
}

vec4 screenToClipSpace(vec2 screenPos) {
    const float z = 0.5;
    return vec4((screenPos/ubo_SIZE)*2-1, z, 1);
}
vec3 screenToWorld(vec2 p) {
    // Convert p to camera space
    vec2 pos = 2*((p+0.5)/ubo_SIZE);
    pos.x -= 1;
    pos.y  = 1-pos.y;
    pos *= ASPECT_RATIO * TANFOV2;

    // Convert pos from camera space to world space
    return (INVVIEW * vec4(pos, -1, 1)).xyz;
}
/// World coords to screen coords.
vec2 worldToScreen(vec3 w) {
    vec3 cam = (VIEW * vec4(w, 1)).xyz;
    vec2 a   = cam.xy / (-cam.z * ASPECT_RATIO * TANFOV2);

    return vec2(a.x+1, 1-a.y) / 2 * ubo_SIZE - 0.5;
}
*/