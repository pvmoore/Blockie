module blockie.render.vk.VKTopBar;

import blockie.render.all;

final class VKTopBar : TopBar {
private:
    @Borrowed VulkanContext context;
    @Borrowed Font font;
    Text text;
    Rectangles rectangles;
public:
    this(VulkanContext context, VKRenderView renderView, uint height) {
        super(renderView, height);

        this.context = context;
        auto camera = Camera2D.forVulkan(context.vk.windowSize());

        this.font = context.fonts.get("dejavusans-bold");
        this.text = new Text(context, font, true, 1000);
        text.camera(camera);
        text.setSize(FONT_SIZE);
        text.setColour(WHITE*1.1);
        text.setDropShadowColour(RGBA(0,0,0, 0.8));
        text.setDropShadowOffset(vec2(-0.0025, 0.0025));

        text.add("[]", 2, 1);        /// 0
        text.add("World", 300, 1);   /// 1
        text.setColour(RGBA(1,0.8,0.2,1));
        text.add("Options", 320, 1); /// 2

        auto width = context.vk.windowSize.width;

        this.rectangles = new Rectangles(context, 1)
            .camera(camera)
            .setColour(RGBA(0.1, 0.1, 0.3, 1));
        this.rectangles
            .add(float2(0,0), float2(width, 0), float2(width, height), float2(0, height));

        renderOptionsChanged();
    }
    override void destroy() {
        super.destroy();

        if(text) text.destroy();
        if(rectangles) rectangles.destroy();
    }
    override void setWorld(World world) {
        super.setWorld(world);

        version(MODEL_B) {
            string b = "-B";
        } else {
            string b = "";
        }
        auto s = "%s (MODEL %s%s)".format(world.name, getModelName(), b);
        float x = world.camera.windowSize().width/2 - font.sdf.getDimension(s, FONT_SIZE).width/2;
        text.replace(1, s)
            .moveTo(1, cast(int)x, 1);
    }
    override void renderOptionsChanged() {
        bool opt1 = renderView.getRenderOption(RenderOption.DISPLAY_VOXEL_SIZES);
        bool opt2 = renderView.getRenderOption(RenderOption.ACCURATE_VOXEL_BOXES);
        text.replace(2,
            (opt1 ? "1" : "-") ~
            (opt2 ? "2" : "-")
        );
    }
    override void update(AbsRenderData renderData) {
        rectangles.beforeRenderPass(renderData.as!VKRenderData.frame);
        text.beforeRenderPass(renderData.as!VKRenderData.frame);
    }
    override void render(AbsRenderData renderData) {
        if(world) {
            /// Display camera position
            text.replace(0, "%s  %s"
                .format(
                    world.camera.position.toString(1),
                    (world.camera.position/CHUNK_SIZE).to!int
                )
            );
        }
        rectangles.insideRenderPass(renderData.as!VKRenderData.frame);
        text.insideRenderPass(renderData.as!VKRenderData.frame);
    }
}