module blockie.render.EventStatsMonitor;

import blockie.render.all;

abstract class EventStatsMonitor : IMonitor {
private:
    IQueue!EventMsg messages;
    EventMsg[100] tempMessages;
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

    abstract void doInitialise();
public:
    this(string name, string label) {
        this.name = name;
        this.label = label;
        this.messages = makeSPSCQueue!EventMsg(1024*8);
    }
    void destroy() {

    }
    EventStatsMonitor formatting(string fmt) {
        this.fmt = fmt;
        return this;
    }
    EventStatsMonitor colour(RGBA c) {
        col = c;
        return this;
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
    EventStatsMonitor initialise() {
        if(eventIds.length > 0) {
            // Subscribe to events
            ulong e = 0;
            foreach(id; eventIds.keys()) e |= id;

            getEvents().subscribe("StatsMonitor::" ~ name, e, messages);
        }

        doInitialise();
        return this;
    }
    EventStatsMonitor move(int2 pos) {
        this.pos = pos;
        return this;
    }
    void update(uint index, double value) {
        values[index] = value;
    }
    void render() {
        auto numMsgs = messages.drain(tempMessages);
        if(numMsgs>0) {
            foreach(i; 0..numMsgs) {
                auto msg = tempMessages[i];

                if(msg.id !in eventIds) {
                    log("msg.id = %s, eventIds = %s #messages on queue = %s",
                        msg.id, eventIds.keys, messages.length());
                    flushLog();
                }

                auto index = eventIds[msg.id];

                values[index] = msg.get!double;
            }
        }
    }
}