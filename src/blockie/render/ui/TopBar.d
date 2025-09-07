module blockie.render.ui.TopBar;

import blockie.render.all;

final class TopBar {
public:
    this(VulkanContext context, VKRenderView renderView, uint height) {
        this.renderView = renderView;
        this.height = height;
        this.context = context;
        this.font = context.fonts.get("dejavusans-bold");
        this.text = new Text(context, font, true, 1000);

        auto camera = Camera2D.forVulkan(context.vk.windowSize());

        text.camera(camera);
        text.setSize(FONT_SIZE);
        text.setColour(WHITE*1.1);
        text.setDropShadowColour(RGBA(0,0,0, 0.8));
        text.setDropShadowOffset(float2(-0.0025, 0.0025));

        text.add("[]", 2, 1);        /// 0
        text.add("World", 300, 1);   /// 1
        text.setColour(RGBA(1,0.8,0.2,1));
        text.add("Options", 370, 1); /// 2

        auto width = context.vk.windowSize.width;

        this.rectangles = new Rectangles(context, 1)
            .camera(camera)
            .setColour(RGBA(0.1, 0.1, 0.3, 1));
        this.rectangles
            .add(float2(0,0), float2(width, 0), float2(width, height), float2(0, height));

        renderOptionsChanged();
    }
    void destroy() {
        if(text) text.destroy();
        if(rectangles) rectangles.destroy();
    }
    void setWorld(World world) {
        this.world = world;

        auto s = "'%s' (MODEL %s)".format(world.name, MODEL);
        float x = world.camera.windowSize().width/2 - font.sdf.getDimension(s, FONT_SIZE).width/2;
        text.replace(1, s)
            .moveTo(1, cast(int)x, 1);
    }
    void renderOptionsChanged() {
        bool opt1 = renderView.getRenderOption(RenderOption.DISPLAY_VOXEL_SIZES);
        bool opt2 = renderView.getRenderOption(RenderOption.ACCURATE_VOXEL_BOXES);
        text.replace(2,
            (opt1 ? "1" : "-") ~
            (opt2 ? "2" : "-")
        );
    }
    void update(AbsRenderData renderData) {
        rectangles.beforeRenderPass(renderData.as!VKRenderData.frame);
        text.beforeRenderPass(renderData.as!VKRenderData.frame);
    }
    void render(AbsRenderData renderData) {
        if(world) {
            /// Display camera position
            text.replace(0, "Camera %s  %s"
                .format(
                    world.camera.position.toString(1),
                    (world.camera.position/CHUNK_SIZE).to!int
                )
            );
        }
        rectangles.insideRenderPass(renderData.as!VKRenderData.frame);
        text.insideRenderPass(renderData.as!VKRenderData.frame);
    }
private:
    enum FONT_SIZE = 15;
    @Borrowed RenderView renderView;
    @Borrowed VulkanContext context;
    @Borrowed Font font;

    World world;
    uint height;
    Text text;
    Rectangles rectangles;
}
