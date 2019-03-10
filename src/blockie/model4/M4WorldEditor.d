module blockie.model4.M4WorldEditor;

import blockie.all;

final class M4WorldEditor : WorldEditor {
protected:
    override void generateDistances() {

        auto addedViews = new DistanceFieldsBiDirChunk(storage, views, 31)
            .generate()
            .getAddedViews();

        this.views ~= addedViews;

        writefln("\t%s views added to the transaction", addedViews.length);
    }
public:
    this(World world, Model model) {
        super(world, model);
    }
private:
}