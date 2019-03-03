module blockie.model3.M3WorldEditor;

import blockie.all;

final class M3WorldEditor : WorldEditor {
protected:
    override void editsCompleted() {
        /// Ensure flags are set correctly before we continue
        foreach(v; views) {
            (cast(M3ChunkEditView)v).root().recalculateFlags();
        }
    }
    override void generateDistances() {
        auto addedViews = new ChunkDistanceFields(storage, views)
            .generate()
            .getAddedViews();

        new CellDistanceFieldsBiDirectional(views, model, 15)
            .generate();

        calcUniqDistances();

        this.views ~= addedViews;

        writefln("\t%s views added to the transaction", addedViews.length);
    }
public:
    this(World world, Model model) {
        super(world, model);
    }
private:
    void calcUniqDistances() {
        writefln("# chunks = %s", views.length);

        uint[Distance3] uniq;
        uint total = 0;

        foreach(v; views) {
            auto c3 = cast(M3ChunkEditView)v;
            if(!c3.isAir) {
                foreach(c; c3.root().cells) {
                    if(c.isAir) {
                        uniq[c.distance]++;
                        total++;
                    }
                }
            }
        }
        writefln("\t#Total = %s", total);
        writefln("\t#Uniq  = %s", uniq.length);
    }
}