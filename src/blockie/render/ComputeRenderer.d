module blockie.render.ComputeRenderer;

import blockie.render.all;

abstract class ComputeRenderer : IRenderer, ChunkManager.SceneChangeListener {
protected:
    RenderView renderView;
    int4 renderRect;
    World world;
    ChunkManager chunkManager;
    Timing renderTiming;
    Timing computeTiming;

    static struct Screen {
        float3 middle;
        float3 xDelta;
        float3 yDelta;
    }

    final Screen calculateScreen() {
        auto camera = world.camera;
        const float Y  = renderRect.y;
        const float w  = renderRect.width;
        const float h  = renderRect.height;
        const float h2 = h/2;
        const float w2 = w/2;
        const float z  = 0;

        float3 cameraPos = world.camera.position();

        float3 left   = camera.screenToWorld(0, Y+h2, z) - cameraPos;
        float3 right  = camera.screenToWorld(w, Y+h2, z) - cameraPos;
        float3 top    = camera.screenToWorld(w2, Y,   z) - cameraPos;
        float3 bottom = camera.screenToWorld(w2, Y+h, z) - cameraPos;

        return Screen(
            camera.screenToWorld(w2, Y+h2, z) - cameraPos,
            (right-left) / w,
            (bottom-top) / h
        );
    }
public:
    this(RenderView renderView, int4 renderRect) {
        this.renderView    = renderView;
        this.renderRect    = renderRect;
        this.renderTiming  = new Timing(10,3);
        this.computeTiming = new Timing(10,3);

        expect((renderRect.width&7)==0, "Width must be multiple of 8. It is %s".format(renderRect.width));
        expect((renderRect.height&7)==0, "Height must be multiple of 8. It is %s".format(renderRect.height));
    }
    void destroy() {
        if(chunkManager) chunkManager.destroy();
    }
    void setWorld(World world) {
        this.world = world;
    }
    void renderOptionsChanged() {
        // Ignore render options
    }
}
