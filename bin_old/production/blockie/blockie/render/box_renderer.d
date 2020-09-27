module blockie.render.box_renderer;

import blockie.all;
/**
 *  Render a rectangle border around the world.
 */
final class BoxRenderer {
    LineRenderer3D lineRenderer;
    vec3 min;
    vec3 max;
    RGBA colour = WHITE;

    this(OpenGL gl) {
        lineRenderer = new LineRenderer3D(gl);
    }
    void destroy() {
        lineRenderer.destroy();
    }
    auto setColour(RGBA c) {
        colour = c;
        return this;
    }
    void update(Camera3D cam, vec3 min, vec3 max) {
        this.min = min;
        this.max = max;
        lineRenderer.setVP(cam.VP);
        lineRenderer.setColour(colour);
        lineRenderer.clear();

        // bottom
        lineRenderer.addLine(
            vec3(min.x, min.y, min.z),
            vec3(max.x,
                    min.y,
                    min.z));
        lineRenderer.addLine(
            vec3(min.x, min.y, min.z),
            vec3(min.x,
                    min.y,
                    max.z));
        lineRenderer.addLine(
            vec3(max.x, min.y, max.z),
            vec3(min.x,
                    min.y,
                    max.z));
        lineRenderer.addLine(
            vec3(max.x, min.y, max.z),
            vec3(max.x,
                    min.y,
                    min.z));

        // top
        lineRenderer.addLine(
            vec3(min.x, max.y, min.z),
            vec3(max.x,
                 max.y,
                 min.z));
        lineRenderer.addLine(
            vec3(min.x, max.y, min.z),
            vec3(min.x,
                 max.y,
                 max.z));
        lineRenderer.addLine(
            vec3(max.x, max.y, max.z),
            vec3(min.x,
                 max.y,
                 max.z));
        lineRenderer.addLine(
            vec3(max.x, max.y, max.z),
            vec3(max.x,
                    max.y,
                    min.z));
        // sides
        lineRenderer.addLine(
            vec3(min.x, min.y, min.z),
            vec3(min.x,
                    max.y,
                    min.z));
        lineRenderer.addLine(
            vec3(max.x, min.y, min.z),
            vec3(max.x,
                    max.y,
                    min.z));
        lineRenderer.addLine(
            vec3(min.x, min.y, max.z),
            vec3(min.x,
                    max.y,
                    max.z));
        lineRenderer.addLine(
            vec3(max.x, min.y, max.z),
            vec3(max.x,
                    max.y,
                    max.z));
    }
    void render() {
        lineRenderer.render();
    }
}

