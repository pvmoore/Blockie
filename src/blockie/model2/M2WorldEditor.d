module blockie.model2.M2WorldEditor;

import blockie.all;

final class M2WorldEditor : WorldEditor {
protected:
    override void editsCompleted() {
        /// Ensure flags are set correctly before we continue
        foreach(v; views) {
            (cast(M2ChunkEditView)v).root().recalculateFlags();
        }
    }
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
