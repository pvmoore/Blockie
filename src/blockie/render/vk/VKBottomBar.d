module blockie.render.vk.VKBottomBar;

import blockie.render.all;

final class VKBottomBar : BottomBar {
private:
    VulkanContext context;
    Text text;
    Font font;
    Rectangles rectangles;
public:
    this(VulkanContext context, VKRenderView renderView) {
        super(renderView);

        this.context = context;
        this.font  = context.fonts.get("dejavusans-bold");
        this.text  = new Text(context, font, true, 1000);

        auto width = context.vk.windowSize.width;
        auto height = context.vk.windowSize.height;
        auto camera = Camera2D.forVulkan(context.vk.windowSize());

        text.setCamera(camera);
        text.setSize(FONT_SIZE);
        text.setColour(WHITE*0.9);
        text.setDropShadowColour(RGBA(0,0,0, 0.8));
        text.setDropShadowOffset(vec2(-0.0025, 0.0025));
        text.appendText("Bottom bar", 2, cast(int)height-20);

        this.rectangles = new Rectangles(context, 1)
            .setCamera(camera)
            .setColour(RGBA(0.1, 0.1, 0.3, 1))
            .addRect(float2(0,height-20), float2(width, height-20), float2(width, height), float2(0, height));
    }
    override void destroy() {
        if(text) text.destroy();
        if(rectangles) rectangles.destroy();
    }
    override void update(AbsRenderData renderData) {
        rectangles.beforeRenderPass(renderData.as!VKRenderData.res);
        text.beforeRenderPass(renderData.as!VKRenderData.res);
    }
    override void render(AbsRenderData renderData) {
        rectangles.insideRenderPass(renderData.as!VKRenderData.res);
        text.insideRenderPass(renderData.as!VKRenderData.res);
    }
}