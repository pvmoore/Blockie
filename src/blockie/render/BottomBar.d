module blockie.render.BottomBar;

import blockie.render.all;

abstract class BottomBar {
protected:
    enum FONT_SIZE = 15;
    Camera2D camera;
    RenderView renderView;
public:
    this(RenderView renderView) {
        this.renderView = renderView;
    }
    abstract void destroy();
    abstract void update(AbsRenderData renderData);
    abstract void render(AbsRenderData renderData);
}