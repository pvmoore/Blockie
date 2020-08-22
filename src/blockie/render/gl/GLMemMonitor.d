module blockie.render.gl.GLMemMonitor;

import blockie.render.all;

final class GLMemMonitor : GLMonitor {
private:
    enum MB = 1024*1024.0;
    ProcessMemInfo procMemInfo;
public:
    this(OpenGL gl) {
        super(gl, "MemMonitor", "RAM (MB)");
    }
    override GLMemMonitor initialise() {
        super.initialise();

        this.procMemInfo = processMemInfo();

        textRenderer
            .setColour(WHITE*0.92)
            .appendText("")
            .appendText("");

        return this;
    }
    override void render() {
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
