module blockie.render.shade_gpgpu_renderer;

import blockie.all;
/**
 *  Use the fragment shader to perform shade computations
 *  and draw the result to the current frame buffer.
 */
final class ShadeGPGPURenderer {
    OpenGL gl;
    IntRect rect;
    VAO vao;
    VBO vbo;
    Program prog;
    uint textureID;

    this(OpenGL gl, IntRect rect) {
        this.gl   = gl;
        this.rect = rect;
        this.vao  = new VAO();
        this.prog = new Program()
            .fromFile("shaders/shade.gpgpu");
        prog.use();
        auto cam = new Camera2D(gl.windowSize);
        prog.setUniform("VP", cam.VP);
        prog.setUniform("ORIGIN", Vector2(rect.x,rect.y));
        prog.setUniform("SIZE", Vector2(rect.w,rect.h));
        prog.setUniform("texData0", 0);
        initVertices();
    }
    void destroy() {
        prog.destroy();
        if(vbo) vbo.destroy();
        vao.destroy();
    }
    void setUniform(T)(string name, T value) {
        prog.use();
        prog.setUniform(name, value);
    }
    void setSource(uint textureID) {
        this.textureID = textureID;
    }
    void render() {
        vao.bind();
        prog.use();

        glActiveTexture(GL_TEXTURE0 + 0);
        glBindTexture(GL_TEXTURE_2D, textureID);

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
private:
    void initVertices() {
        const int ELEMENT_SIZE   = Vector2.sizeof;
        const long bytesRequired = 4*ELEMENT_SIZE;

        vao.bind();
        vbo = VBO.array(bytesRequired, GL_STATIC_DRAW);

        // 0--2  (0,1,2)
        // | /|
        // |/ |
        // 1--3
        Vector2[] vertices = [
            Vector2(rect.x,         rect.y),
            Vector2(rect.x,         rect.y+rect.h),
            Vector2(rect.x+rect.w,  rect.y),
            Vector2(rect.x+rect.w,  rect.y+rect.h)
        ];
        vbo.addData(vertices);
        vao.enableAttrib(0, 2, GL_FLOAT, false, ELEMENT_SIZE, 0);
    }
}


