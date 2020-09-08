module blockie.render.gl.GLConsole;

import blockie.render.all;

final class GLConsole : Console {
private:
    SDFFontRenderer textRenderer;
public:
    this(OpenGL gl, uint y) {
        super(y);

        auto font = gl.getFont("roboto-bold");
        this.textRenderer = new SDFFontRenderer(gl, font, false);
        auto camera = new Camera2D(gl.windowSize());
        textRenderer.setSize(FONT_SIZE);
        textRenderer.setVP(camera.VP);
        textRenderer.setColour(WHITE*0.9);
    }
    override void destroy() {
        super.destroy();
        textRenderer.destroy();
    }
    override void update(AbsRenderData renderData) {

    }
    override void render(AbsRenderData renderData) {
        textRenderer.clearText();

        long start = buffer.length-30;
        if(start<0) start = 0;

        int y = ypos;
        for(auto i=start; i<buffer.length; i++) {
            textRenderer.appendText(buffer[i], 0, y);
            y += 25;
        }
        textRenderer.render();
    }
}

