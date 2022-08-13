module blockie.render.stat_providers;

import blockie.render.all;

interface StatProvider {
    void tick();
    float getValue(int index);
}
//══════════════════════════════════════════════════════════════════════════════════════════════════
final class TimingStatProvider : StatProvider {
private:
    @Borrowed Timing timing;
    int depth;
    float value;
public:
    this(Timing timing, int depth) {
        this.timing = timing;
        this.depth = depth;
    }
    override float getValue(int index) { return value; }
    override void tick() {
        this.value = timing.average(depth);
    }
}
//══════════════════════════════════════════════════════════════════════════════════════════════════
final class FpsStatProvider : StatProvider {
private:
    @Borrowed Vulkan vk;
    float value;
public:
    this(Vulkan vk) {
        this.vk = vk;
    }
    override float getValue(int index) { return value; }
    override void tick() {
        this.value = 1_000_000_000.0 / vk.getFrameTimeNanos();
    }
}
//══════════════════════════════════════════════════════════════════════════════════════════════════
final class EventStatProvider : StatProvider {
private:
    string name;
    bool subscribed = false;
    IQueue!EventMsg messages;
    EventMsg[100] tempMessages;
    uint[ulong] eventIds;
    float[] values;
public:
    override float getValue(int index) { return values[index]; }

    this(string name) {
        this.name = name;
        this.messages = makeSPSCQueue!EventMsg(1024*8);
    }
    auto addEvent(EventID eventId) {
        eventIds[eventId.as!ulong] = eventIds.length.as!uint;
        values ~= 0;
        return this;
    }
    auto initialise() {
        subscribeToEvents();
        return this;
    }
    override void tick() {
        vkassert(subscribed);

        auto numMsgs = messages.drain(tempMessages);
        if(numMsgs==0) return;

        foreach(i; 0..numMsgs) {
            auto msg = tempMessages[i];

            if(msg.id == EventID.STORAGE_READ) {
                this.log("STORAGE_READ: %s", msg.get!double);
            }

            auto index = eventIds[msg.id];

            values[index] = cast(float)msg.get!double;
        }
    }
private:
    void subscribeToEvents() {
        // Subscribe to events
        ulong e = 0;
        foreach(id; eventIds.keys()) e |= id;

        getEvents().subscribe("EventCollector::" ~ name, e, messages);
        subscribed = true;
    }
}