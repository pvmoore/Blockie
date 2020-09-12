module blockie.render.vk.VKConsole;

import blockie.render.all;

final class VKConsole : Console {
private:
    @Borrowed VulkanContext context;
public:
    this(VulkanContext context, uint y) {
        super(y);
        this.context = context;
    }
    override void destroy() {

    }
    override void update(AbsRenderData renderData) {

    }
    override void render(AbsRenderData renderData) {

    }
}