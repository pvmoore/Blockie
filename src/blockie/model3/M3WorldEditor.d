module blockie.model3.M3WorldEditor;

import blockie.all;

final class M3WorldEditor : WorldEditor {
protected:
    override void generateDistances() {

        auto addedViews = new DistanceFieldsBiDirChunk(storage, views, 31)
            .generate()
            .getAddedViews();

        new DistanceFieldsBiDirCell(views, model, 15)
            .generate();

        this.views ~= addedViews;

        writefln("\t%s views added to the transaction", addedViews.length); flushConsole();
    }
public:
    this(World world, Model model) {
        super(world, model);
    }
}