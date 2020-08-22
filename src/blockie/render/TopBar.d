module blockie.render.TopBar;

import blockie.render.all;

abstract class TopBar {
private:

protected:
    enum FONT_SIZE = 15;
    RenderView renderView;
    World world;
    uint height;
public:
    this(RenderView renderView, uint height) {
        this.renderView = renderView;
        this.height = height;
    }
    void destroy() {

    }
    void setWorld(World world) {
        this.world = world;
    }
    void renderOptionsChanged() {

    }
    abstract void render();
}
