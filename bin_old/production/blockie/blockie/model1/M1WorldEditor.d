module blockie.model1.M1WorldEditor;

import blockie.all;

final class M1WorldEditor : WorldEditor {
protected:
    override void generateDistances() {

        auto addedViews = new DistanceFieldsBiDirChunk(storage, views, 31)
                            .generate()
                            .getAddedViews();

        new DistanceFieldsUniDirCell(views, 1<<model.numRootBits(), 255)
            .generate();

        this.views ~= addedViews;

        writefln("\t%s views added to the transaction", addedViews.length);
    }
public:
    this(World world, Model model) {
        super(world, model);
    }
}