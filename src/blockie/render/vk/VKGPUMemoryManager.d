module blockie.render.vk.VKGPUMemoryManager;

import blockie.render.all;

final class VKGPUMemoryManager(T) : IGPUMemoryManager!T {
private:
    GPUData!T decorated;
    Allocator allocs;
public:
    this(GPUData!T decorated) {
        this.decorated = decorated;
        this.allocs    = new Allocator(decorated.numBytes);
    }
    @Implements("IGPUMemoryManager")
    ulong getNumBytesUsed() {
        return allocs.numBytesUsed();
    }
    @Implements("IGPUMemoryManager")
    void bind() {
        // Nothing to do
    }
    @Implements("IGPUMemoryManager")
    long write(T[] data) {
        auto o = allocs.alloc(data.length * T.sizeof, 4);
        if(o==-1) throw new Error("Out of buffer memory");

        // Write data starting at offset
        decorated.write(data, o.as!uint / T.sizeof);

        return o;
    }
    @Implements("IGPUMemoryManager")
    void free(ulong offset, ulong size) {
        return allocs.free(offset, size);
    }
}