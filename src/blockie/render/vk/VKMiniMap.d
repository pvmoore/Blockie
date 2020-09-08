module blockie.render.vk.VKMiniMap;

import blockie.render.all;

final class VKMiniMap : MiniMap {
private:
    VulkanContext context;
public:
    this(VulkanContext context) {
        this.context = context;
        auto camera  = Camera2D.forVulkan(context.vk.windowSize());
    }
    override void destroy() {

    }
    override void setWorld(World world) {
        super.setWorld(world);
    }
    override void update(AbsRenderData renderData) {

    }
    override void render(AbsRenderData renderData) {

    }
}