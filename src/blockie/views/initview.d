module blockie.views.initview;

import blockie.all;

final class InitView : IView {
private:
    const float FONT_SIZE = 50;
    OpenGL gl;
    Font font;
    SDFFontRenderer text;
    Camera2D camera2d;
    Dimension winSize;
    Mutex lock;
    struct { // locked
        uint percent;
        string message;
    }
public:
    this(OpenGL gl) {
        this.gl         = gl;
        this.font       = gl.getFont("dejavusans");
        this.text       = new SDFFontRenderer(gl, font, false);
        this.winSize    = gl.windowSize();
        this.camera2d   = new Camera2D(winSize);
        this.lock       = new Mutex;

        Rect rect = font.sdf.getRect("Creating World", FONT_SIZE);
        text.setSize(FONT_SIZE);
        text.setVP(camera2d.VP);
        text.setColour(WHITE);
        text.appendText(
            "Creating World",
            cast(int)(winSize.width/2 - rect.width/2),
            cast(int)(winSize.height/2 - rect.height/2) - 100
        );
        rect = font.sdf.getRect("  1 %", FONT_SIZE);
        text.appendText(
            "  0 %",
            cast(int)(winSize.width/2 - rect.width/2),
            cast(int)(winSize.height/2 - rect.height/2) - 50
        );
        text.setColour(YELLOW);
        text.appendText("");
    }
    void destroy() {
        text.destroy();
    }
    void enteringView() {
        glClearColor(0.15, 0, 0, 1);

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);

        percent = 0;
    }
    void exitingView() {

    }
    void update(float timeDelta) {

    }
    void worldGenerationCallback(int percentComplete, string msg=null) {
        lock.lock();
        scope(exit) lock.unlock();
        percent = percentComplete;
        if(msg && msg.length>0) {
            message = msg;
            //writefln(msg); flushStdErrOut();
        }
    }
    void render(long frameNumber, long normalisedFrameNumber, float timeDelta) {
        glClear(GL_COLOR_BUFFER_BIT);

        string percentStr = "% 3u %%".format(percent);
        Rect rect = font.sdf.getRect(percentStr, FONT_SIZE);
        text.replaceText(1,
            percentStr,
            cast(int)(winSize.width/2 - rect.width/2),
            cast(int)(winSize.height/2 - rect.height/2) - 50);

        rect = font.sdf.getRect(message, FONT_SIZE);
        text.replaceText(2,
            message,
            cast(int)(winSize.width/2 - rect.width/2),
            cast(int)(winSize.height/2 - rect.height/2));

        text.render();
    }
}