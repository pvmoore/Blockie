module blockie.render.vk.VKMemMonitor;

import blockie.render.all;

final class VKMemMonitor : VKMonitor {
private:
    enum MB = 1024*1024.0;
    ProcessMemInfo procMemInfo;
public:
    this(VulkanContext context) {
        super(context, "MemMonitor", "RAM (MB)");
    }
    override VKMemMonitor initialise() {
        super.initialise();

        this.procMemInfo = processMemInfo();

        text.setColour(WHITE*0.92)
            .add("", 0, 0);
        text.add("", 0, 0);

        return this;
    }
    override void update(AbsRenderData renderData) {
        //GC.collect();
        //GC.minimize();
        procMemInfo.update();

        text.replace(1, "Used ...... %6.1f".format(procMemInfo.usedRAM()/MB))
            .move(1, pos.x, pos.y+16);

        text.replace(2, "Reserved .. %6.1f".format(procMemInfo.usedVirtMem()/MB))
            .move(2, pos.x, pos.y+16+16);
    }
}