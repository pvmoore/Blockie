module blockie.render.ui.HistogramUI;

import blockie.render.all;

final class HistogramUI {
private:
    const int NUM_DATAPOINTS;
    string title;
    string fmt;
    StatProvider statProvider;

    ContiguousCircularBuffer!float buf;
    ContiguousCircularBuffer!float avgBuf;

    float value = 0;
    float maximum = 1;
    float average = 0;
    float averageTotal = 0;
    bool open;
public:
    this(string title, int numDataPoints, string fmt, StatProvider statProvider) {
        this.title = title;
        this.NUM_DATAPOINTS = numDataPoints;
        this.fmt = fmt ~ "\0";
        this.statProvider = statProvider;
        this.buf = new ContiguousCircularBuffer!float(NUM_DATAPOINTS);
        this.avgBuf = new ContiguousCircularBuffer!float(NUM_DATAPOINTS);

        // pre-fill with zeroes
        foreach(i; 0..NUM_DATAPOINTS) {
            buf.add(0);
        }
        foreach(i; 0..NUM_DATAPOINTS) {
            buf.take();
        }
    }
    auto setOpen() {
        this.open = true;
        return this;
    }
    void tick() {
        statProvider.tick();
        this.value = statProvider.getValue(0);

        float sub = 0;

        if(buf.size() == NUM_DATAPOINTS) {
            sub = buf.take();
        }
        buf.add(value);

        averageTotal += value;
        averageTotal -= sub;

        average = averageTotal/buf.size();
        if(avgBuf.size() == NUM_DATAPOINTS) {
            avgBuf.take();
        }
        avgBuf.add(average);

        if(average*1.1 > maximum) {
            maximum = average*1.1;
        }
    }
    void render() {
        if(igCollapsingHeader(title.ptr, open ? ImGuiTreeNodeFlags_DefaultOpen : 0)) {

            igPlotHistogram_FloatPtr(
                "",
                buf.slice().ptr,
                NUM_DATAPOINTS,
                0,              // offset into values
                "",
                0,              // scale min
                maximum,        // scale max
                ImVec2(300,80),
                float.sizeof
            );

            igSameLine(-3, 0);

            igPlotLines_FloatPtr(
                "",
                avgBuf.slice().ptr,
                NUM_DATAPOINTS,
                0,
                fmt.format(average).ptr,
                0,
                maximum,
                ImVec2(300,80),
                float.sizeof
            );
        }
    }
}