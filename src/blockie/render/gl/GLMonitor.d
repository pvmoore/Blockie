module blockie.render.gl.GLMonitor;

import blockie.render.all;

class GLMonitor : EventStatsMonitor {
protected:
    OpenGL gl;
    SDFFontRenderer textRenderer;

    override void doInitialise() {
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
    }
public:
    this(OpenGL gl, string name, string label) {
        super(name, label);
        this.gl = gl;
    }
    override void destroy() {
        super.destroy();
        if(textRenderer) textRenderer.destroy();
    }
    override GLMonitor move(int2 pos) {
        super.move(pos);

        if(label) {
            textRenderer.replaceText(0, label, pos.x, pos.y);
        }
        return this;
    }
    override void render() {
        super.render();

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

        textRenderer.render();
    }
}