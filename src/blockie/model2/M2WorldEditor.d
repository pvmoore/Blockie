module blockie.model2.M2WorldEditor;

import blockie.all;

final class M2WorldEditor : WorldEditor {
protected:
    override void generateDistances() {

        auto addedViews = new DistanceFieldsBiDirChunk(storage, views, 31)
            .generate()
            .getAddedViews();

        new DistanceFieldsBiDirCell(views, model, 15)
            .generate();

        this.views ~= addedViews;

        writefln("\t%s views added to the transaction", addedViews.length);
    }
public:
    this(World world, Model model) {
        super(world, model);
    }
}
