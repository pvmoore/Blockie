module blockie.render.gl.minimap;

import blockie.render.all;

version(OPENGL):

final class MiniMap {
private:
    OpenGL gl;
    Camera2D camera;
    World world;
public:
    this(OpenGL gl) {
        this.gl = gl;
        this.camera = new Camera2D(gl.windowSize());
    }
    void destroy() {

    }
    void setWorld(World world) {
        this.world = world;
    }
    void render() {

    }
}

