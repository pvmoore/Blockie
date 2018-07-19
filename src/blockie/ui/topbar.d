module blockie.ui.topbar;

import blockie.all;

final class TopBar {
private:
    const int FONT_SIZE = 16;
    World world;
    Font font;
    SDFFontRenderer textRenderer;
    FilledRectangleRenderer rectRenderer;
public:
    this(OpenGL gl, uint height) {
        this.font = gl.getFont("dejavusans-bold");
        this.textRenderer = new SDFFontRenderer(gl, font, false);
        this.rectRenderer = new FilledRectangleRenderer(gl);
        auto camera2d = new Camera2D(gl.windowSize);
        textRenderer.setSize(FONT_SIZE);
        textRenderer.setVP(camera2d.VP);
        textRenderer.setColour(WHITE*1.0);
        textRenderer.appendText("[]", 2, 1);
        textRenderer.appendText("World", 300, 1);

        rectRenderer.setVP(camera2d.VP);
        rectRenderer.addRectangle(
            vec2(0,0),
            vec2(gl.windowSize.width, height),
            RGBA(0.1, 0.1, 0.3, 1)
        );
    }
    void destroy() {
        textRenderer.destroy();
        rectRenderer.destroy();
    }
    void setWorld(World world) {
        this.world = world;
        float x = world.camera.windowSize().width/2 - font.sdf.getDimension(world.name,FONT_SIZE).width/2;
        textRenderer.replaceText(1, world.name, cast(int)x);
    }
    void render() {
        rectRenderer.render();

        if(world) {
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

