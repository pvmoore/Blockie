module blockie.render.gl.GLBlockie;

import blockie.render.all;

final class GLBlockie : Blockie, ApplicationListener {
protected:
    OpenGL gl;
    GLRenderData renderData;
public:
    this() {
        this.renderData = new GLRenderData();
    }
    override void initialise() {
        super.initialise();

        this.gl = new OpenGL(this, (h) {
            h.width         = WIDTH;
            h.height        = HEIGHT;
            h.title         = title;
            h.windowed      = true;
            h.showWindow    = false;
            h.samples       = 0;
            h.glVersionMaj  = 4;
            h.glVersionMin  = 3;
            h.fontDirectory = "/pvmoore/_assets/fonts/hiero/";
        });

        this.renderView = new GLRenderView(gl);

        import core.cpuid: processor;
        string deviceName = cast(string)fromStringz(glGetString(GL_RENDERER));
        title ~= " :: OpenGL (%sx%s) :: %s :: %s".format(WIDTH, HEIGHT, processor().strip(), deviceName);

        gl.setWindowTitle(title);

        //auto t = task(&initWorld);
        //t.executeInNewThread();
        initWorld(gl.windowSize);

        gl.showWindow(true);
    }
    override void destroy() {
        super.destroy();

        if(gl) gl.destroy();
        gl = null;
    }
    override void run() {
        if(gl) gl.enterMainLoop();
    }
    @Implements("ApplicationListener")
    override void keyPress(uint keyCode, uint scanCode, bool down, uint mods) nothrow {
        try{
            renderView.keyPress(keyCode, down, mods);
        }catch(Exception e) {}
    }
    @Implements("ApplicationListener")
    override void mouseButton(uint button, float x, float y, bool down, uint mods) nothrow {

    }
    @Implements("ApplicationListener")
	override void mouseMoved(float x, float y) nothrow {

    }
    @Implements("ApplicationListener")
	override void mouseWheel(float xdelta, float ydelta, float x, float y) nothrow {

    }
    /// always called on the main thread
    @Implements("ApplicationListener")
    override void render(ulong frameNumber, float seconds, float perSecond) {
        if(!gl) return;
        if(nextView) {
            if(view) view.exitingView();
            view = nextView;
            view.enteringView();
            nextView = null;
        }
        if(!view) return;

        renderData.frameNumber = frameNumber;
        renderData.seconds = seconds;
        renderData.perSecond = perSecond;

        view.update(renderData);
        view.render(renderData);

//        if((frameNumber&255)==0) {
//            writefln("Event subscribers {");
//            foreach(t; getEvents().getSubscriberStats) {
//                writefln("\t%s :  mask=%x time=%s millis msgs=%s", t[0], t[1], t[2]/1000000.0, t[3]);
//            }
//            writefln("}");
//        }
    }
}
