module blockie.render.gl.GLMinimap;

import blockie.render.all;

final class GLMinimap {
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

