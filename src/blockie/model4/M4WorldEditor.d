module blockie.model4.M4WorldEditor;

import blockie.all;

final class M4WorldEditor : WorldEditor {
protected:
    override void editsCompleted() {
        /// Ensure flags are set correctly before we continue
        foreach(v; views) {
            (cast(M4ChunkEditView)v).root().recalculateFlags();
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
            auto c4 = cast(M4ChunkEditView)v;
            if(!c4.isAir) {
                foreach(c; c4.root().cells) {
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