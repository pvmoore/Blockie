module blockie.render.gl.GLMinimap;

import blockie.render.all;

final class GLMinimap : MiniMap {
private:
    OpenGL gl;
public:
    this(OpenGL gl) {
        super();

        this.gl = gl;
        auto camera = new Camera2D(gl.windowSize());
    }
    override void destroy() {
        super.destroy();
    }
    override void update(AbsRenderData renderData) {

    }
    override void render(AbsRenderData renderData) {

    }
}

