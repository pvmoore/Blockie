module blockie.views.iview;

import blockie.all;

public:

import blockie.views.renderview;

interface IView {
    void enteringView();
    void render(long frameNumber, long normalisedFrameNumber, float timeDelta);
    void update(float timeDelta);
    void exitingView();
    void destroy();
}
