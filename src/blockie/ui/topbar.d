module blockie.ui.topbar;

import blockie.all;

final class TopBar {
private:
    const int FONT_SIZE = 16;
    RenderView renderView;
    World world;
    Font font;
    SDFFontRenderer textRenderer;
    FilledRectangleRenderer rectRenderer;
public:
    this(OpenGL gl, RenderView renderView, uint height) {
        this.renderView = renderView;
        this.font = gl.getFont("dejavusans-bold");
        this.textRenderer = new SDFFontRenderer(gl, font, false);
        this.rectRenderer = new FilledRectangleRenderer(gl);
        auto camera2d = new Camera2D(gl.windowSize);
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
    void destroy() {
        textRenderer.destroy();
        rectRenderer.destroy();
    }
    void setWorld(World world) {
        this.world = world;

        /// Display world name
        version(MODEL1) {
            const model = 1;
        } else version(MODEL2) {
            const model = 2;
        } else version(MODEL3) {
            const model = 3;
        } else {
            const model = 4;
        }
        auto text = "%s (MODEL %s)".format(world.name, model);
        float x = world.camera.windowSize().width/2 - font.sdf.getDimension(text,FONT_SIZE).width/2;
        textRenderer.replaceText(1, text, cast(int)x);
    }
    void renderOptionsChanged() {
        /// Display RenderOptions
        bool opt1 = renderView.getRenderOption(RenderOption.DISPLAY_VOXEL_SIZES);
        bool opt2 = renderView.getRenderOption(RenderOption.ACCURATE_VOXEL_BOXES);
        textRenderer.replaceText(2,
            (opt1 ? "1" : "-") ~
            (opt2 ? "2" : "-")
        );
    }
    void render() {
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

