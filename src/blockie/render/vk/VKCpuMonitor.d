module blockie.render.vk.VKCpuMonitor;

import blockie.render.all;
import std.parallelism : totalCPUs;
import std.math : round;

final class VKCpuMonitor : VKMonitor {
private:
    PDH pdh;
    int numCPUs;
public:
    this(VulkanContext context) {
        super(context, "CPUMonitor", "CPU");
    }
    override VKCpuMonitor initialise() {
        super.initialise();

        this.pdh          = new PDH(1000);
        this.numCPUs      = totalCPUs;

        this.text
            .setColour(WHITE*0.98)
            .appendText("Average  |0|")
            .setColour(WHITE*0.93);

        for(auto i=0; i<numCPUs; i++) {
            text.appendText("");
        }

        return this;
    }
    override void destroy() {
        super.destroy();
        pdh.destroy();
    }
    override void update(AbsRenderData renderData) {
        double total   = pdh.getCPUTotalPercentage();
        double[] cores = pdh.getCPUPercentagesByCore();

        string _fmt(double v) {
            int a = cast(int)round(v/10);
            return "O".repeat(a) ~ ".".repeat(10-a);
        }

        text.replaceText(1, "Average   |%s|".format(_fmt(total)), pos.x, pos.y+16);

        int y = pos.y+16+16;
        foreach(i, d; cores) {
            text.replaceText(cast(int)i+2, "Thread %02s |%s|".format(i, _fmt(d)), pos.x, y);
            y += 16;
        }
        text.beforeRenderPass(renderData.as!VKRenderData.frame);
    }
}