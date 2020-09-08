
#ifdef VULKAN
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
#else
    uniform uvec3 WORLD_CHUNKS_XYZ; // (25, 8, 25)
    uniform vec3  WORLD_BB[2];      // world bounding box in worldcoords
    uniform vec3  SUN_POS;          // in worldcoords

    uniform ivec2 SIZE;             // Render window size
    uniform vec3  CAMERA_POS;       // in worldcoords
    uniform vec3  SCREEN_MIDDLE;    // for calculating Ray
    uniform vec3  SCREEN_XDELTA;    // for calculating Ray
    uniform vec3  SCREEN_YDELTA;    // for calculating Ray

    #define ubo_SIZE                (SIZE)
    #define ubo_WORLD_BB_MIN        (WORLD_BB[0])
    #define ubo_WORLD_BB_MAX        (WORLD_BB[1])
    #define ubo_WORLD_CHUNKS_XYZ    (WORLD_CHUNKS_XYZ)
    #define ubo_SUN_POS             (SUN_POS)
    #define ubo_CAMERA_POS          (CAMERA_POS)
    #define ubo_SCREEN_MIDDLE       (SCREEN_MIDDLE)
    #define ubo_SCREEN_XDELTA       (SCREEN_XDELTA)
    #define ubo_SCREEN_YDELTA       (SCREEN_YDELTA)
#endif