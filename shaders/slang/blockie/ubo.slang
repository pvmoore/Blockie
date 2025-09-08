#language slang 2026
implementing blockie;

public struct UBO {
    /*   0 */ public uint2 size;
    /*     */ public uint2 _0;
    /*  16 */ public float3 sunPos;
    /*     */ public float _1;
    /*  32 */ public uint3 worldChunksXYZ;
    /*     */ public uint _2;
    /*  48 */ public int3 worldBBMin;
    /*     */ public int _3;
    /*  64 */ public int3 worldBBMax;
    /*     */ public int _4;
    /*  80 */ public float3 cameraPos;
    /*     */ public float _5;
    /*  96 */ public float3 screenMiddle;
    /*     */ public float _6;
    /* 112 */ public float3 screenXDelta;
    /*     */ public float _7;
    /* 128 */ public float3 screenYDelta;
    /*     */ public float _8;
    /* 144 */

    public float3 chunksMul() { 
        return float3(1, worldChunksXYZ.x, worldChunksXYZ.x * worldChunksXYZ.y); 
    }
} 
