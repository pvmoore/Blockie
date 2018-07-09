module blockie.ui.monitors;
/**
 *
 */
import blockie.all;

private {
    __gshared CPUMonitor cpuMonitor;
    __gshared MEMMonitor memMonitor;
    __gshared MultiValueMonitor!double diskMonitor;
    __gshared MultiValueMonitor!double gpuioMonitor;
    __gshared MultiValueMonitor!ulong chunksMonitor;
    __gshared MultiValueMonitor!double fpsMonitor;
    __gshared MultiValueMonitor!double updateTimeMonitor;
    __gshared MultiValueMonitor!double frameTimeMonitor;
    __gshared MultiValueMonitor!double computeMonitor;
}
shared static this() {
    cpuMonitor  = new CPUMonitor;
    memMonitor  = new MEMMonitor;
    diskMonitor = new MultiValueMonitor!double(2, "Disk (MB) ")
        .colour(WHITE*0.9)
        .formatting("3.1f")
        .setValue(0,0,"Read ... ")
        .setValue(1,0,"Write .. ");
    gpuioMonitor = new MultiValueMonitor!double(5, "GPU (MB)")
        .colour(WHITE*0.9)
        .formatting("4.2f")
        .setValue(0, 0, "Writes ........ ")
        .setValue(1, 0, "Used (vx) ... ")
        .setValue(2, 0, "Used (ch) .. ", "K")
        .setValue(3, 0, "Cam updt .. ","ms")
        .setValue(4, 0, "Chk updt ... ","ms");
    chunksMonitor = new MultiValueMonitor!ulong(4, "Chunks")
        .colour(WHITE*0.9)
        .formatting("u")
        .setValue(0, 0, "Total ......")
        .setValue(1, 0, "On GPU ..")
        .setValue(2, 0, "Ready .....")
        .setValue(3, 0, "Flywt ......");
    fpsMonitor = new MultiValueMonitor!double(1, null)
        .colour(WHITE*0.9)
        .formatting("4.2f")
        .setValue(0, 0, "FPS ....... ");
    updateTimeMonitor = new MultiValueMonitor!double(1, null)
        .colour(WHITE*0.9)
        .formatting("4.2f")
        .setValue(0, 0, "Update .. ", "ms");
    frameTimeMonitor = new MultiValueMonitor!double(1, null)
        .colour(WHITE*0.9)
        .formatting("4.2f")
        .setValue(0,0, "Frame ... ", "ms");
    computeMonitor = new MultiValueMonitor!double(2, "Compute")
        .colour(WHITE*0.9)
        .formatting("5.2f")
        .setValue(0,0, "Render .....", "ms")
        .setValue(1,0, "Compute ..", "ms");
}

void destroyMonitors() {
    cpuMonitor.destroy();
    memMonitor.destroy();
    diskMonitor.destroy();
    gpuioMonitor.destroy();
    chunksMonitor.destroy();
    fpsMonitor.destroy();
    updateTimeMonitor.destroy();
    frameTimeMonitor.destroy();
    computeMonitor.destroy();
}

auto getCPUMonitor() { return cpuMonitor; }
auto getMEMMonitor() { return memMonitor; }
auto getDiskMonitor() { return diskMonitor; }
auto getGPUIOMonitor() { return gpuioMonitor; }
auto getChunksMonitor() { return chunksMonitor; }
auto getFPSMonitor() { return fpsMonitor; }
auto getUpdateTimeMonitor() { return updateTimeMonitor; }
auto getFrameTimeMonitor() { return frameTimeMonitor; }
auto getComputeMonitor() { return computeMonitor; }

//=======================================================
final class CPUMonitor {
private:
    const float FONT_SIZE = 28;
    OpenGL gl;
    Camera2D camera;
    SDFFontRenderer textRenderer;
    PDH pdh;
    ivec2 pos;
    int numCPUs;
public:
    auto init(OpenGL gl) {
        import std.parallelism : totalCPUs;
        this.gl  = gl;
        this.pos = pos;
        this.pdh = new PDH(1000);
        this.numCPUs = totalCPUs;
        auto font = gl.getFont("segoe-ui-black");
        this.textRenderer = new SDFFontRenderer(gl, font, true);
        this.camera = new Camera2D(gl.windowSize());
        textRenderer.setDropShadowColour(BLACK);
        textRenderer.setSize(FONT_SIZE);
        textRenderer.setVP(camera.VP);

        textRenderer
            .setColour(WHITE*1.1)
            .appendText("CPU")
            .setColour(WHITE*0.9)
            .appendText("");

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

        textRenderer.replaceText(1,
            "Average ... %4.1f".format(total),
            pos.x, pos.y+35);

        int y = pos.y+35+25;
        foreach(i, d; cores) {
            textRenderer.replaceText(
                cast(int)i+2,
                "Core %s ...... %4.1f".format(i, d),
                pos.x, y);
            y += 25;
        }
        textRenderer.render();
    }
}
//========================================================
final class MEMMonitor {
private:
    const float FONT_SIZE = 28;
    const double MB = 1024*1024;
    OpenGL gl;
    Camera2D camera;
    ProcessMemInfo procMemInfo;
    SDFFontRenderer textRenderer;
ivec2 pos;
public:
    auto init(OpenGL gl) {
        this.gl  = gl;
        this.pos = pos;

        this.procMemInfo = processMemInfo();
        auto font = gl.getFont("segoe-ui-black");

        this.textRenderer = new SDFFontRenderer(gl, font, true);
        this.camera = new Camera2D(gl.windowSize());
        textRenderer.setDropShadowColour(BLACK);
        textRenderer.setSize(FONT_SIZE);
        textRenderer.setVP(camera.VP);

        textRenderer
            .setColour(WHITE*1.1)
            .appendText("Memory (MB)")
            .setColour(WHITE*0.9)
            .appendText("")
            .appendText("");

        return this;
    }
    void destroy() {
        textRenderer.destroy();
    }
    auto move(ivec2 pos) {
        this.pos = pos;
        textRenderer.replaceText(0,"Memory (MB)", pos.x, pos.y);
        return this;
    }
    void render() {
        //GC.collect();
        //GC.minimize();
        procMemInfo.update();

        textRenderer.replaceText(1, "Used ......... %6.1f".format(
         procMemInfo.usedRAM()/MB
        ), pos.x, pos.y+35);

        textRenderer.replaceText(2, "Reserved .. %6.1f".format(
         procMemInfo.usedVirtMem()/MB
        ), pos.x, pos.y+35+25);

        textRenderer.render();
    }
}
//========================================================
final class MultiValueMonitor(T) {
private:
    const float FONT_SIZE = 28;
    OpenGL gl;
    Camera2D camera;
    SDFFontRenderer textRenderer;
    ivec2 pos;
    RGBA col = WHITE;
    string label;
    string fmt = "5.2f";
    string[] prefixes;
    string[] suffixes;
    T[] values;
public:
    this(int numValues, string label) {
        this.label  = label;
        this.values.length = numValues;
        this.prefixes.length = numValues;
        this.suffixes.length = numValues;
        values[] = 0;
    }
    auto init(OpenGL gl) {
        this.gl  = gl;
        this.pos = pos;
        auto font = gl.getFont("segoe-ui-black");
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

        foreach(v; values) {
            textRenderer
                .setColour(col)
                .appendText("");
        }

        return this;
    }
    void destroy() {
        textRenderer.destroy();
    }
    auto formatting(string fmt) {
        this.fmt = fmt;
        return this;
    }
    auto colour(RGBA c) {
        col = c;
        return this;
    }
    auto move(ivec2 pos) {
        this.pos = pos;
        if(label) {
            textRenderer.replaceText(0, label, pos.x, pos.y);
        }
        return this;
    }
    auto setValues(T[] v...) {
        values[] = v[];
        return this;
    }
    auto setValue(int index, T v) {
        values[index] = v;
        return this;
    }
    auto setValue(int index,
                  T v,
                  string prefix,
                  string suffix="")
    {
        values[index] = v;
        prefixes[index] = prefix;
        suffixes[index] = suffix;
        return this;
    }
    void render() {
        uint n = 0;
        int y = pos.y;

        if(label) {
            n++;
            y += 35;
        }

        foreach(i, v; values) {
            textRenderer.replaceText(
                n++,
                prefixes[i] ~ ("%"~fmt).format(v) ~ suffixes[i],
                pos.x,
                y
            );
            y += 25;
        }

        textRenderer.render();
    }
}