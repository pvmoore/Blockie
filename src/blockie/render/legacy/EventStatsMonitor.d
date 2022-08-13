module blockie.render.legacy.EventStatsMonitor;

import blockie.render.all;

abstract class StatsMonitor : IMonitor {
protected:
    enum FONT_SIZE = 14;
    string name;
    Camera2D camera;
    int2 pos;
    RGBA col = WHITE;
    string label;
    string fmt = "5.2f";
    uint[ulong] eventIds;
    string[] prefixes;
    string[] suffixes;
    double[] values;
public:
    this(string name, string label) {
        this.name = name;
        this.label = label;
    }
    void destroy() {

    }
    StatsMonitor addValue(string prefix, string suffix = "") {
        prefixes ~= prefix;
        suffixes ~= suffix;
        values   ~= 0;
        return this;
    }
    StatsMonitor formatting(string fmt) {
        this.fmt = fmt;
        return this;
    }
    StatsMonitor colour(RGBA c) {
        col = c;
        return this;
    }
    StatsMonitor initialise() {
        return this;
    }
    StatsMonitor move(int2 pos) {
        this.pos = pos;
        return this;
    }
    void updateValue(uint index, double value) {
        values[index] = value;
    }
    abstract void update(AbsRenderData renderData);
    abstract void render(AbsRenderData renderData);
}

abstract class EventStatsMonitor : StatsMonitor {
private:
    IQueue!EventMsg messages;
    EventMsg[100] tempMessages;
protected:
public:
    this(string name, string label) {
        super(name, label);
        this.messages = makeSPSCQueue!EventMsg(1024*8);
    }
    EventStatsMonitor addValue(EventID eventId, string prefix, string suffix = "") {
        if(eventId != 0) {
            eventIds[eventId.as!ulong] = eventIds.length.as!uint;
        }
        prefixes ~= prefix;
        suffixes ~= suffix;
        values   ~= 0;
        return this;
    }
    override EventStatsMonitor initialise() {
        if(eventIds.length > 0) {
            // Subscribe to events
            ulong e = 0;
            foreach(id; eventIds.keys()) e |= id;

            getEvents().subscribe("StatsMonitor::" ~ name, e, messages);
        }

        super.initialise();
        return this;
    }
    override void update(AbsRenderData renderData) {
        auto numMsgs = messages.drain(tempMessages);
        if(numMsgs>0) {
            foreach(i; 0..numMsgs) {
                auto msg = tempMessages[i];

                if(msg.id !in eventIds) {
                    log("msg.id = %s, eventIds = %s #messages on queue = %s",
                        msg.id, eventIds.keys, messages.length());
                }

                auto index = eventIds[msg.id];

                values[index] = msg.get!double;
            }
        }
    }
}
