module blockie.render.ui.StatsMonitorUI;

import blockie.render.all;

final class StatusMonitorUI {
private:
    string title;
    uint[ulong] eventIds;
    string[] prefixes;
    string[] suffixes;
    string[] fmts;
    float[] values;
    IQueue!EventMsg messages;
    EventMsg[100] tempMessages;
public:
    this(string title) {
        this.title = title;
        this.messages = makeSPSCQueue!EventMsg(1024*8);
    }
    void initialise() {
        // Subscribe to events
        ulong e = 0;
        foreach(id; eventIds.keys()) e |= id;

        getEvents().subscribe("StatusMonitorUI::" ~ title, e, messages);
    }
    auto addValue(EventID eventId, string prefix, string fmt, string suffix) {
        eventIds[eventId.as!ulong] = eventIds.length.as!uint;
        prefixes ~= prefix;
        fmts     ~= "%%s%s%%s\0".format(fmt);
        suffixes ~= suffix;
        values   ~= 0;
        return this;
    }
    void tick() {
        auto numMsgs = messages.drain(tempMessages);
        if(numMsgs>0) {
            foreach(i; 0..numMsgs) {
                auto msg = tempMessages[i];

                if(msg.id !in eventIds) {
                    this.log("msg.id = %s, eventIds = %s #messages on queue = %s",
                        msg.id, eventIds.keys, messages.length());
                }

                auto index = eventIds[msg.id];

                values[index] = cast(float)msg.get!double;
            }
        }
    }
    void render() {
        auto count = values.length;
        if(igCollapsingHeader(title.ptr, ImGuiTreeNodeFlags_DefaultOpen)) {

            igPushStyleVar_Vec2(ImGuiStyleVar_ItemSpacing, ImVec2(0,0));

            foreach(i; 0..count) {
                igText(fmts[i].format(prefixes[i], values[i].as!float, suffixes[i]).ptr);
            }

            igPopStyleVar(1);
        }
    }
}