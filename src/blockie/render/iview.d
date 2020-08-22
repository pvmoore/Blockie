module blockie.render.iview;

import blockie.render.all;

interface IView {
    void destroy();
    void enteringView();
    void exitingView();
    bool isReady();
    void update(float timeDelta);
    void render(ulong frameNumber, float seconds, float perSecond);
}
