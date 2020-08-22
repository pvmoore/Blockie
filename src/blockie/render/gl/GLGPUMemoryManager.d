module blockie.render.gl.GLGPUMemoryManager;

import blockie.render.all;

final class GLGPUMemoryManager : IGPUMemoryManager {
private:
    VBOMemoryManager decorated;
public:
    this(VBOMemoryManager decorated) {
        this.decorated = decorated;
    }
    @Implements("IGPUMemoryManager")
    ulong getNumBytesUsed() {
        return decorated.numBytesUsed;
    }
    @Implements("IGPUMemoryManager")
    void bind() {
        decorated.bind();
    }
    @Implements("IGPUMemoryManager")
    long write(ubyte[] data) {
        return decorated.write(data, 4);
    }
    @Implements("IGPUMemoryManager")
    long write(uint[] data) {
        return decorated.write(data, 4);
    }
    @Implements("IGPUMemoryManager")
    void free(ulong offset, ulong size) {
        decorated.free(offset, size);
    }
}