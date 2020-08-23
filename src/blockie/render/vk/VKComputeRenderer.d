module src.blockie.render.vk.VKComputeRenderer;

import blockie.render.all;

final class VKComputeRenderer : IRenderer, ChunkManager.SceneChangeListener {
private:
    VulkanContext context;
    RenderView renderView;
    int4 renderRect;
    World world;
    ChunkManager chunkManager;
public:
    this(VulkanContext context, RenderView renderView, int4 renderRect) {
        this.context    = context;
        this.renderView = renderView;
        this.renderRect = renderRect;
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