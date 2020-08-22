module blockie.render.gl.GLBottomBar;

import blockie.render.all;

final class GLBottomBar : BottomBar {
private:
    SDFFontRenderer textRenderer;
    FilledRectangleRenderer rectRenderer;
public:
    this(OpenGL gl, GLRenderView renderView) {
        super(renderView);

        auto font         = gl.getFont("dejavusans-bold");
        this.textRenderer = new SDFFontRenderer(gl, font, false);
        this.rectRenderer = new FilledRectangleRenderer(gl);
        this.camera = new Camera2D(gl.windowSize);

        auto dim = gl.windowSize();
        textRenderer.setSize(FONT_SIZE);
        textRenderer.setVP(camera.VP);
        textRenderer.setColour(WHITE*0.9);
        textRenderer.appendText("Bottom bar", 2, cast(int)dim.height-20);

        rectRenderer.setVP(camera.VP);
        rectRenderer.addRectangle(
            vec2(0, dim.height-20),
            vec2(dim.width, dim.height),
            RGBA(0.1, 0.1, 0.3, 1)
        );
    }
    override void destroy() {
        super.destroy();
        textRenderer.destroy();
        rectRenderer.destroy();
    }
    override void render() {
        rectRenderer.render();
        textRenderer.render();
    }
}

