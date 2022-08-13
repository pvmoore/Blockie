module blockie.render.ui.MemStatsUI;

import blockie.render.all;

final class MemStatsUI {
    import core.memory : GC;
private:
    uint used, reserved;
    uint numCollections;
    ulong totalCollectionTime;
public:
    void tick() {
        uint free = (GC.stats.freeSize / (1024*1024)).to!uint;
        used = (GC.stats.usedSize / (1024*1024)).to!uint;

        reserved = (free+used);

        numCollections = GC.profileStats.numCollections.to!uint;
        totalCollectionTime = GC.profileStats.totalCollectionTime.total!"msecs";
    }
    void render() {
        if(igCollapsingHeader("GC Memory", ImGuiTreeNodeFlags_DefaultOpen)) {
            igText("Used ......... %d MB", used);
            igText("Reserved .. %d MB", reserved);
            igText("# collections .. %d", numCollections);
            igText("Collection time .. %d ms", totalCollectionTime);
        }
    }
}