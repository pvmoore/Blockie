module blockie.render.vk.VKGPUMemoryManager;

import blockie.render.all;

final class VKGPUMemoryManager : IGPUMemoryManager {
private:
    Vulkan vk;
public:
    this(Vulkan vk) {
        this.vk = vk;
    }
    @Implements("IGPUMemoryManager")
    ulong getNumBytesUsed() {
        return 0;
    }
    @Implements("IGPUMemoryManager")
    void bind() {

    }
    @Implements("IGPUMemoryManager")
    long write(ubyte[] data) {
        return -1;
    }
    @Implements("IGPUMemoryManager")
    long write(uint[] data) {
        return -1;
    }
    @Implements("IGPUMemoryManager")
    void free(ulong offset, ulong size) {

    }
}