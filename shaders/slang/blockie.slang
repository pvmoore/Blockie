#language slang 2026
module blockie;

__include blockie.camera;
__include blockie.march;
__include blockie.position;
__include blockie.simplex_noise_3d;
__include blockie.shade;
__include blockie.ubo;

public static const float PI          = float.getPi(); 

public const static uint UINT_MAX     = uint.maxValue;
public static const float FLT_MAX     = float.maxValue;
public static const float FLT_MIN     = float.minValue;
public static const float FLT_INF     = 1.0f/0.0f;
public static const float FLT_EPSILON = 1.192092896e-07f;

// Common chunk constants 
public static const int CHUNK_SIZE     = 1024;
public static const int CHUNK_SIZE_SHR = 10;
public static const int MAX_DISTANCE   = 15000;

public typedef StructuredBuffer<uint, ScalarDataLayout> VoxelsBuffer;
public typedef StructuredBuffer<uint, ScalarDataLayout> ChunksBuffer;

public typedef RWStructuredBuffer<MarchOut, ScalarDataLayout> MarchOutputBuffer;
public typedef StructuredBuffer<MarchOut, ScalarDataLayout> MarchInputBuffer;

public struct Ray {
    public float3 start;
    public float3 direction;
    public float3 invDirection;

    public __init(float3 start, float3 direction) {
        this.start        = start;
        this.direction    = direction;
        this.invDirection = 1.0f/direction;
    }
}

public struct Voxel {
    public uint size;      // 0,1,2,4,8,16,32,64,128,256,512,1024
    public uint value;     // 0 or 1 (Model2)
    public uint oct;       // only required for cells
    public float distance; // Hit distance from camera
}

public struct MarchOut { // 8 bytes
    public float distance;
    public uint voxel;
}

///
/// Truncate vector to an axis aligned normal.
///
public float3 normaliseToAxis(float3 v) {
    float3 a = abs(v);
    float3 b = a.x>=a.y && a.x>=a.z ? float3(1,0,0) :
             a.y>=a.z ? float3(0,1,0) : float3(0,0,1);
    return b * sign(v);
}
