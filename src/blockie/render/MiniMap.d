module blockie.render.MiniMap;

import blockie.render.all;

abstract class MiniMap {
private:

protected:
    Camera2D camera;
    World world;
public:
    this() {

    }
    void destroy() {

    }
    void setWorld(World world) {
        this.world = world;
    }
    abstract void render();
}