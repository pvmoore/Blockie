module blockie.render.ui.Console;

import blockie.render.all;

abstract class Console {
protected:
    enum FONT_SIZE = 16;
    int ypos;
    string[] buffer;
public:
    this(int y) {
        this.ypos = y;
    }
    void destroy() {

    }
    Console log(string s) {
        buffer ~= s;
        return this;
    }
    Console clear() {
        buffer.length = 0;
        return this;
    }
    abstract void update(AbsRenderData renderData);
    abstract void render(AbsRenderData renderData);
}
