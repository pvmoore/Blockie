module blockie.model5.M5WorldEditor;

import blockie.all;

final class M5WorldEditor : WorldEditor {
protected:
    override void generateDistances() {

        auto addedViews = new DistanceFieldsBiDirChunk(storage, views, 31)
            .generate()
            .getAddedViews();

        new DistanceFieldsBiDirCell(views, 1<<model.numRootBits(), 31)
            .generate();

        this.views ~= addedViews;

        writefln("\t%s views added to the transaction", addedViews.length); flushConsole();
    }
public:
    this(World world, Model model) {
        super(world, model);
    }
}