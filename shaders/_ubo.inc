
layout(set = 0, binding = 3, std140) uniform UBO {
    /*   0 */ uvec2 size;
    /*     */ uvec2 _0;
    /*  16 */ vec3 sunPos;
    /*     */ float _1;
    /*  32 */ uvec3 worldChunksXYZ;
    /*     */ uint _2;
    /*  48 */ ivec3 worldBBMin;
    /*     */ int _3;
    /*  64 */ ivec3 worldBBMax;
    /*     */ int _4;
    /*  80 */ vec3 cameraPos;
    /*     */ float _5;
    /*  96 */ vec3 screenMiddle;
    /*     */ float _6;
    /* 112 */ vec3 screenXDelta;
    /*     */ float _7;
    /* 128 */ vec3 screenYDelta;
    /*     */ float _8;
    /* 144 */
} ubo;

#define ubo_SIZE                (ubo.size)
#define ubo_WORLD_BB_MIN        (ubo.worldBBMin)
#define ubo_WORLD_BB_MAX        (ubo.worldBBMax)
#define ubo_WORLD_CHUNKS_XYZ    (ubo.worldChunksXYZ)
#define ubo_SUN_POS             (ubo.sunPos)
#define ubo_CAMERA_POS          (ubo.cameraPos)
#define ubo_SCREEN_MIDDLE       (ubo.screenMiddle)
#define ubo_SCREEN_XDELTA       (ubo.screenXDelta)
#define ubo_SCREEN_YDELTA       (ubo.screenYDelta)