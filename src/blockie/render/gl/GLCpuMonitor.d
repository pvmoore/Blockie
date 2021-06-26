module blockie.render.gl.GLCPUMonitor;

import blockie.render.all;
import std.parallelism : totalCPUs;
import std.math : round;

final class GLCpuMonitor : GLMonitor {
private:
    PDH pdh;
    int numCPUs;
public:
    this(OpenGL gl) {
        super(gl, "CPUMonitor", "CPU");
    }
    override GLCpuMonitor initialise() {
        super.initialise();

        this.pdh          = new PDH(1000);
        this.numCPUs      = totalCPUs;

        this.textRenderer
            .setColour(WHITE*0.98)
            .appendText("Average  |0|", 0, 0)
            .setColour(WHITE*0.93);

        for(auto i=0; i<numCPUs; i++) {
            textRenderer.appendText("", 0, 0);
        }

        // !!! For some reason this does not work any more.
        // It returns a PDH_CSTATUS_NO_COUNTER error.
        // This works fine when testing in the common project though.

        //pdh.start();

        return this;
    }
    override void destroy() {
        super.destroy();
        if(pdh) pdh.destroy();
    }
    override void update(AbsRenderData renderData) {
        double total   = pdh.getCPUTotalPercentage();
        double[] cores = pdh.getCPUPercentagesByCore();

        string _fmt(double v) {
            int a = cast(int)round(v/10);
            return "O".repeat(a) ~ ".".repeat(10-a);
        }

        textRenderer.replaceText(1, "Average   |%s|".format(_fmt(total)), pos.x, pos.y+16);

        int y = pos.y+16+16;
        foreach(i, d; cores) {
            textRenderer.replaceText(cast(int)i+2, "Thread %02s |%s|".format(i, _fmt(d)), pos.x, y);
            y += 16;
        }
    }
}