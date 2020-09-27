module blockie.render.irenderer;

import blockie.all;

interface IRenderer {
    void render();
    void afterUpdate(bool cameraMoved);
    void setWorld(World w);
    void destroy();
}

