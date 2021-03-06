module blockie.render.vk.VKMonitor;

import blockie.render.all;

class VKMonitor : EventStatsMonitor {
protected:
    @Borrowed VulkanContext context;
    Text text;
public:
    this(VulkanContext context, string name, string label) {
        super(name, label);
        this.context = context;
    }
    override void destroy() {
        super.destroy();
        if(text) text.destroy();
    }
    override VKMonitor initialise() {
        super.initialise();

        this.camera = Camera2D.forVulkan(context.vk.windowSize());

        this.text = new Text(context, context.fonts.get("dejavusansmono-bold"), true, 1000);
        text.camera(camera);
        text.setSize(FONT_SIZE);
        text.setColour(WHITE*1.1);
        text.setDropShadowColour(RGBA(0,0,0, 0.8));
        text.setDropShadowOffset(vec2(-0.0025, 0.0025));

        if(label) {
            text.add("", 0, 0);
        }
        foreach(i; 0..values.length) {
            text.setColour(col);
            text.add("", 0, 0);
        }
        return this;
    }
    override VKMonitor move(int2 pos) {
        super.move(pos);

        if(label) {
            text.replace(0, label)
                .move(0, pos.x, pos.y);
        }
        return this;
    }
    override void update(AbsRenderData renderData) {
        super.update(renderData);

        uint n = 0;
        int y = pos.y;

        if(label) {
            n++;
            y += 16;
        }

        foreach(i, v; values) {
            text.replace(n, prefixes[i] ~ ("%"~fmt).format(v) ~ suffixes[i])
                .move(n, pos.x, y);

            n++;
            y += 16;
        }
        text.beforeRenderPass(renderData.as!VKRenderData.frame);
    }
    override void render(AbsRenderData res) {
        text.insideRenderPass(res.as!VKRenderData.frame);
    }
}