module blockie.render.legacy.MiniMap;

import blockie.render.all;

abstract class MiniMap {
protected:
    World world;
public:
    this() {

    }
    void destroy() {

    }
    void setWorld(World world) {
        this.world = world;
    }
    abstract void update(AbsRenderData renderData);
    abstract void render(AbsRenderData renderData);
}