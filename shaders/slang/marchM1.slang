#language slang 2026

import blockie;
import m1;

// todo - think about using ByteAddressBuffer 
// todo - use ScalarDataLayout for ubo
[[vk::binding(0, 0)]] VoxelsBuffer voxelsIn;
[[vk::binding(1, 0)]] ChunksBuffer chunkDataIn;
[[vk::binding(2, 0)]] MarchOutputBuffer dataOut; 
[[vk::binding(3, 0)]] ConstantBuffer<UBO, Std140DataLayout> ubo; 

[shader("compute")]
[numthreads(8,8,1)]
void main(uint3 threadId : SV_DispatchThreadID) {
    float2 pixel    = float2(threadId.xy);
    uint imageIndex = threadId.x + (threadId.y*ubo.size.x);

    Ray ray      = generateRay(ubo, pixel);
    Position pos = Position(ubo, ray.start);

    Voxel voxel  = march(chunkDataIn, voxelsIn, ubo, ray, pos);

    dataOut[imageIndex] = MarchOut(voxel.distance, voxel.value);
}
