module blockie.render.BottomBar;

import blockie.render.all;

abstract class BottomBar {
private:

protected:
    enum FONT_SIZE = 15;
    Camera2D camera;
    RenderView renderView;
public:
    this(RenderView renderView) {
        this.renderView = renderView;
    }
    void destroy() {

    }
    abstract void render();
}