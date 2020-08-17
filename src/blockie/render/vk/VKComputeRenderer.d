module src.blockie.render.vk.VKComputeRenderer;

import blockie.all;

version(VULKAN):

final class VKComputeRenderer : IRenderer, ChunkManager.SceneChangeListener {
private:
    World world;
    ChunkManager chunkManager;  // gl specific
    //RenderView renderView;      // gl specific

public:
    this() {

    }
    @Implements("IRenderer")
    void destroy() {
        if(chunkManager) chunkManager.destroy();
    }
    @Implements("IRenderer")
    void setWorld(World w) {
        this.world = world;
        //this.chunkManager = new ChunkManager(
        //    this,
        //    world,
        //    marchVoxelsInVBO.getMemoryManager(),
        //    marchChunksInVBO.getMemoryManager()
        //);
    }
    @Implements("IRenderer")
    void render() {

    }
    @Implements("IRenderer")
    void afterUpdate(bool cameraMoved) {

    }
    @Implements("SceneChangeListener")
    void boundsChanged(uvec3 chunksDim, worldcoords minBB, worldcoords maxBB) {

    }
}