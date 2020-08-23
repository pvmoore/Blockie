module blockie.render.vk.VKRenderView;

import blockie.render.all;

final class VKRenderView : RenderView {
private:
    VulkanContext context;
    SkyBox skybox;
    ImageMeta cubeMap;
public:
    this(VulkanContext context) {
        super(vk.windowSize());

        this.context         = context;
        this.computeRenderer = new VKComputeRenderer(context, this, renderRect);
        this.skybox          = new SkyBox(context, cubeMap);

        initialiseMonitors();
    }
    @Implements("RenderView")
    override void destroy() {
        super.destroy();

        if(skybox) skybox.destroy();
        if(computeRenderer) computeRenderer.destroy();
    }
    @Implements("RenderView")
    override void enteringView() {
        super.enteringView();

    }
    override void setWorld(World world) {
        super.setWorld(world);

    }
protected:
    override void afterUpdate(bool cameraMoved, float perSecond) {
        if(cameraMoved) {
            skybox.camera(world.camera);
        }
        computeRenderer.afterUpdate(cameraMoved);
    }
    override void doRender(ulong frameNumber, float seconds, float perSecond) {

        //skybox.render();
        computeRenderer.render();
    }
    override bool isKeyPressed(uint key) {
        return vk.isKeyPressed(key);
    }
    override bool isMouseButtonPressed(uint button) {
        return vk.isMouseButtonPressed(0);
    }
    override float getFps() {
        return vk.getFPS();
    }
}