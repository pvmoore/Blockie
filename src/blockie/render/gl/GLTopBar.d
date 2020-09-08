module blockie.render.gl.GLTopBar;

import blockie.render.all;

final class GLTopBar : TopBar {
private:
    SDFFontRenderer textRenderer;
    FilledRectangleRenderer rectRenderer;
    Font font;
public:
    this(OpenGL gl, GLRenderView renderView, uint height) {
        super(renderView, height);

        auto camera2d = new Camera2D(gl.windowSize);

        this.font = gl.getFont("dejavusans-bold");
        this.textRenderer = new SDFFontRenderer(gl, font, false);
        this.rectRenderer = new FilledRectangleRenderer(gl);

        textRenderer.setSize(FONT_SIZE);
        textRenderer.setVP(camera2d.VP);
        textRenderer.setColour(WHITE*1.0);

        textRenderer.appendText("[]", 2, 1);        /// 0
        textRenderer.appendText("World", 300, 1);   /// 1
        textRenderer.setColour(RGBA(1,0.8,0.2,1));
        textRenderer.appendText("Options", 320, 1); /// 2

        rectRenderer.setVP(camera2d.VP);
        rectRenderer.addRectangle(
            vec2(0,0),
            vec2(gl.windowSize.width, height),
            RGBA(0.1, 0.1, 0.3, 1)
        );
        renderOptionsChanged();
    }
    override void destroy() {
        super.destroy();
        textRenderer.destroy();
        rectRenderer.destroy();
    }
    override void setWorld(World world) {
        super.setWorld(world);

        auto text = "%s (MODEL %s)".format(world.name, getModelName());
        float x = world.camera.windowSize().width/2 - font.sdf.getDimension(text, FONT_SIZE).width/2;
        textRenderer.replaceText(1, text, cast(int)x);
    }
    override void renderOptionsChanged() {
        /// Display RenderOptions
        bool opt1 = renderView.getRenderOption(RenderOption.DISPLAY_VOXEL_SIZES);
        bool opt2 = renderView.getRenderOption(RenderOption.ACCURATE_VOXEL_BOXES);
        textRenderer.replaceText(2,
            (opt1 ? "1" : "-") ~
            (opt2 ? "2" : "-")
        );
    }
    override void update(AbsRenderData renderData) {
        // Nothing to do
    }
    override void render(AbsRenderData renderData) {
        rectRenderer.render();

        if(world) {
            /// Display camera position
            textRenderer.replaceText(0, "%s  %s"
                .format(
                    world.camera.position.toString(1),
                    (world.camera.position/CHUNK_SIZE).to!int
                )
            );
        }

        textRenderer.render();
    }
}

