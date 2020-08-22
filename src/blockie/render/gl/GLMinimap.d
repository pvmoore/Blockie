module blockie.render.gl.GLMinimap;

import blockie.render.all;

final class GLMinimap : MiniMap {
private:
    OpenGL gl;
public:
    this(OpenGL gl) {
        super();

        this.gl = gl;
        this.camera = new Camera2D(gl.windowSize());
    }
    override void destroy() {
        super.destroy();
    }
    override void render() {

    }
}

