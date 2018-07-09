module blockie.render.swrenderer;

import blockie.all;
import blockie.render.raymarcher;

const EPSILON = 0.01;

final class SWSceneRenderer : IRenderer {
private:
    OpenGL gl;
    World world;
    PixelBuffer pixelBuffer;
    LineRenderer3D lineRenderer;
    Pixel[] pixels;
    Ray[] rays;
    Thread thread;
    RayMarcher rayMarcher;
    shared bool ready = false;
    shared bool running = true;
    Timing renderTiming;
    Vector3 camX, camY;
public:
    this(OpenGL gl) {
        this.gl = gl;
        this.lineRenderer  = new LineRenderer3D(gl);
        auto dim = gl.windowSize();
        this.pixelBuffer   = new PixelBuffer(gl, Vector2(0,26), dim.w.toInt, dim.h.toInt-(26+26));
        this.pixels.length = pixelBuffer.width*pixelBuffer.height;
        this.rays.length   = pixelBuffer.width*pixelBuffer.height;

        this.rayMarcher = new RayMarcher(
            pixels, rays,
            pixelBuffer.width, pixelBuffer.height
        );
        this.thread = new Thread(&generate);
        this.renderTiming = new Timing(4);
        thread.isDaemon = false;
        thread.start();
    }
    void destroy() {
        running = false;
        lineRenderer.destroy();
        pixelBuffer.destroy();
    }
    void setWorld(World world) {
        this.world = world;
        cameraMoved();
        atomicStore(ready, true);
    }
    void cameraMoved() {
        auto camera = world.camera;
        lineRenderer.setVP(camera.VP);

        const int Y = 26;
        int w       = pixelBuffer.width;
        int h       = pixelBuffer.height;
        int h2      = h/2;
        int w2      = w/2;

        Vector3 cameraPos = camera.position();
        Vector3 left   = camera.screenToWorld(0, Y+h2, 0.1) - cameraPos;
        Vector3 right  = camera.screenToWorld(w, Y+h2, 0.1) - cameraPos;
        Vector3 top    = camera.screenToWorld(w2, Y, 0.1) - cameraPos;
        Vector3 bottom = camera.screenToWorld(w2, Y+h, 0.1) - cameraPos;
        Vector3 middle = camera.screenToWorld(w2, Y+h2, 0.1) - cameraPos;

        Vector3 xDelta = (right-left) / w;
        Vector3 yDelta = (bottom-top) / h;

        Vector3 ytemp = (middle - w2*xDelta) - h2*yDelta;
        int r = 0;
        for(auto y = 0; y<h; y++) {
            Vector3 temp = ytemp;
            for(auto x=0; x<w; x++) {
                rays[r++].set(
                    cameraPos,
                    temp.normalised()
                );
                temp += xDelta;
            }
            ytemp += yDelta;
        }
    }
    void chunkUpdated(Chunk chunk) {

    }
    void render() {
        pixelBuffer.blitToScreen();
    }
    void debugToConsole(Console console) {
        // origin
        lineRenderer.addLine(Vector3(0,0,0),Vector3(1,0,0)*100, YELLOW);
        lineRenderer.addLine(Vector3(0,0,0),Vector3(0,1,0)*100, WHITE);
        lineRenderer.addLine(Vector3(0,0,0),Vector3(0,0,1)*100, PINK);
        lineRenderer.render();
        lineRenderer.clear();

        console.log("Render time ..... %.2f (%.2f) %.2f millis"
            .format(renderTiming.lowest,
                    renderTiming.average,
                    renderTiming.highest));
    }
private:
    /// runs in different thread
    void generate() {
        while(running) {
            if(atomicLoad(ready)) {
                renderTiming.startFrame();
                rayMarcher.generate(world);
                renderTiming.endFrame();

                pixelBuffer.pixels[] = pixels[];
            } else {
                Thread.sleep(dur!("msecs")(100));
            }
        }
    }
}

