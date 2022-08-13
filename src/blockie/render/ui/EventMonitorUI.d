module blockie.render.ui.EventMonitorUI;

import blockie.render.all;

final class EventMonitorUI {
private:
    string title;
    EventStatProvider statProvider;
    string[] prefixes;
    string[] suffixes;
    string[] fmts;
    bool open;
public:
    this(string title) {
        this.title = title;
        this.statProvider = new EventStatProvider(title);
    }
    auto addValue(EventID eventId, string prefix, string fmt, string suffix) {
        statProvider.addEvent(eventId);
        prefixes ~= prefix;
        fmts     ~= "%%s%s%%s\0".format(fmt);
        suffixes ~= suffix;
        return this;
    }
    auto setOpen() {
        this.open = true;
        return this;
    }
    auto initialise() {
        statProvider.initialise();
        return this;
    }
    void tick() {
        statProvider.tick();
    }
    void render() {
        auto count = fmts.length.as!int;
        if(igCollapsingHeader(title.ptr, open ? ImGuiTreeNodeFlags_DefaultOpen : 0)) {

            igPushStyleVar_Vec2(ImGuiStyleVar_ItemSpacing, ImVec2(0,0));

            foreach(int i; 0..count) {
                igText(fmts[i].format(prefixes[i], statProvider.getValue(i), suffixes[i]).ptr);
            }

            igPopStyleVar(1);
        }
    }
}