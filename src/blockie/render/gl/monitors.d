module blockie.render.gl.monitors;

import blockie.render.all;

final class CPUMonitor {
private:
    const float FONT_SIZE = 14;
    OpenGL gl;
    Camera2D camera;
    SDFFontRenderer textRenderer;
    PDH pdh;
    ivec2 pos;
    int numCPUs;
public:
    auto initialise(OpenGL gl) {
        import std.parallelism : totalCPUs;
        this.gl           = gl;
        this.pos          = pos;
        this.pdh          = new PDH(1000);
        this.numCPUs      = totalCPUs;
        auto font         = gl.getFont("dejavusansmono-bold");
        this.textRenderer = new SDFFontRenderer(gl, font, true);
        this.camera       = new Camera2D(gl.windowSize());
        textRenderer.setDropShadowColour(BLACK);
        textRenderer.setSize(FONT_SIZE);
        textRenderer.setVP(camera.VP);

        textRenderer
            .setColour(WHITE*1.1)
            .appendText("CPU")
            .setColour(WHITE*0.98)
            .appendText("")
            .setColour(WHITE*0.93);

        for(auto i=0; i<numCPUs; i++) {
            textRenderer.appendText("");
        }

        return this;
    }
    void destroy() {
        textRenderer.destroy();
        pdh.destroy();
    }
    auto move(ivec2 pos) {
        this.pos = pos;
        textRenderer.replaceText(0,"CPU",pos.x, pos.y);
        return this;
    }
    void render() {
        double total   = pdh.getCPUTotalPercentage();
        double[] cores = pdh.getCPUPercentagesByCore();

        string _fmt(double v) {
            import std.math : round;
            int a = cast(int)round(v/10);
            return "O".repeat(a) ~ ".".repeat(10-a);
        }

        textRenderer.replaceText(1, "Average  |%s|".format(_fmt(total)), pos.x, pos.y+16);

        int y = pos.y+16+16;
        foreach(i, d; cores) {
            textRenderer.replaceText(cast(int)i+2, "Thread %s |%s|".format(i, _fmt(d)), pos.x, y);
            y += 16;
        }
        textRenderer.render();
    }
}
//========================================================
final class MEMMonitor {
private:
    const float FONT_SIZE = 14;
    const double MB = 1024*1024;
    OpenGL gl;
    Camera2D camera;
    ProcessMemInfo procMemInfo;
    SDFFontRenderer textRenderer;
ivec2 pos;
public:
    auto initialise(OpenGL gl) {
        this.gl  = gl;
        this.pos = pos;

        this.procMemInfo = processMemInfo();
        auto font = gl.getFont("dejavusansmono-bold");

        this.textRenderer = new SDFFontRenderer(gl, font, true);
        this.camera = new Camera2D(gl.windowSize());
        textRenderer.setDropShadowColour(BLACK);
        textRenderer.setSize(FONT_SIZE);
        textRenderer.setVP(camera.VP);

        textRenderer
            .setColour(WHITE*1.1)
            .appendText("RAM (MB)")
            .setColour(WHITE*0.92)
            .appendText("")
            .appendText("");

        return this;
    }
    void destroy() {
        textRenderer.destroy();
    }
    auto move(ivec2 pos) {
        this.pos = pos;
        textRenderer.replaceText(0,"RAM (MB)", pos.x, pos.y);
        return this;
    }
    void render() {
        //GC.collect();
        //GC.minimize();
        procMemInfo.update();

        textRenderer.replaceText(1, "Used ...... %6.1f".format(
         procMemInfo.usedRAM()/MB
        ), pos.x, pos.y+16);

        textRenderer.replaceText(2, "Reserved .. %6.1f".format(
         procMemInfo.usedVirtMem()/MB
        ), pos.x, pos.y+16+16);

        textRenderer.render();
    }
}
//========================================================

final class GLMonitor : StatsMonitor {
private:
    OpenGL gl;
    SDFFontRenderer textRenderer;
protected:
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