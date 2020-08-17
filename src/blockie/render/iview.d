module blockie.render.iview;

import blockie.render.all;

public:

interface IView {
    void enteringView();
    void render(long frameNumber, long normalisedFrameNumber, float timeDelta);
    void update(float timeDelta);
    void exitingView();
    void destroy();
}
