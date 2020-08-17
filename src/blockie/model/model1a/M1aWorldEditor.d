module blockie.model.model1a.M1aWorldEditor;

import blockie.model;

final class M1aWorldEditor : WorldEditor {
protected:
    override void generateDistances() {

        auto addedViews = new DistanceFieldsBiDirChunk(storage, views, 31)
            .generate()
            .getAddedViews();

        new DistanceFieldsBiDirCell(views, 1<<model.numRootBits(), 15)
            .generate();

        this.views ~= addedViews;

        writefln("%s views added to the transaction", addedViews.length);
    }
public:
    this(World world, Model model) {
        super(world, model);
    }
}