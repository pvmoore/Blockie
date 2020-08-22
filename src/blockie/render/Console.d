module blockie.render.Console;

import blockie.render.all;

abstract class Console {
private:

protected:
    enum FONT_SIZE = 16;
    Camera2D camera;
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
    abstract void render();
}
