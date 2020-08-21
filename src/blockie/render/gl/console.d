module blockie.render.gl.console;

import blockie.render.all;

final class Console {
private:
    const float FONT_SIZE = 16;
    Camera2D camera;
    SDFFontRenderer textRenderer;
    string[] buffer;
    int ypos;
public:
    this(OpenGL gl, uint y) {
        this.ypos = y;
        auto font = gl.getFont("roboto-bold");
        this.textRenderer = new SDFFontRenderer(gl, font, false);
        this.camera = new Camera2D(gl.windowSize());
        textRenderer.setSize(FONT_SIZE);
        textRenderer.setVP(camera.VP);
        textRenderer.setColour(WHITE*0.9);
    }
    void destroy() {
        textRenderer.destroy();
    }
    auto log(string s) {
        buffer ~= s;
        return this;
    }
    auto clear() {
        buffer.length = 0;
        return this;
    }
    void render() {
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

