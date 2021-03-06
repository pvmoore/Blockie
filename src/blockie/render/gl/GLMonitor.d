module blockie.render.gl.GLMonitor;

import blockie.render.all;

class GLMonitor : EventStatsMonitor {
protected:
    OpenGL gl;
    SDFFontRenderer textRenderer;
public:
    this(OpenGL gl, string name, string label) {
        super(name, label);
        this.gl = gl;
    }
    override void destroy() {
        super.destroy();
        if(textRenderer) textRenderer.destroy();
    }
    override GLMonitor initialise() {
        super.initialise();

        auto font = gl.getFont("dejavusansmono-bold");
        this.textRenderer = new SDFFontRenderer(gl, font, true);
        this.camera = new Camera2D(gl.windowSize());
        textRenderer.setDropShadowColour(BLACK);
        textRenderer.setSize(FONT_SIZE);
        textRenderer.setVP(camera.VP);

        if(label) {
            textRenderer
                .setColour(WHITE*1.1)
                .appendText(label);
        }

        foreach(i; 0..values.length) {
            textRenderer
                .setColour(col)
                .appendText("");
        }
        return this;
    }
    override GLMonitor move(int2 pos) {
        super.move(pos);

        if(label) {
            textRenderer.replaceText(0, label, pos.x, pos.y);
        }
        return this;
    }
    override void update(AbsRenderData renderData) {
        super.update(renderData);

        uint n = 0;
        int y = pos.y;

        if(label) {
            n++;
            y += 16;
        }

        foreach(i, v; values) {
            textRenderer.replaceText(
                n++,
                prefixes[i] ~ ("%"~fmt).format(v) ~ suffixes[i],
                pos.x,
                y
            );
            y += 16;
        }
    }
    override void render(AbsRenderData renderData) {
        textRenderer.render();
    }
}