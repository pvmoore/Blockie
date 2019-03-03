module blockie.model2.M2WorldEditor;

import blockie.all;

final class M2WorldEditor : WorldEditor {
protected:
    override void generateDistances() {
        new ChunkDistanceFields(storage, chunks)
            .generate();

        new CellDistanceFieldsBiDirectional(chunks, model, 15)
            .generate();

        calcUniqDistances();
    }
public:
    this(World world, Model model) {
        super(world, model);
    }
private:
    void calcUniqDistances() {
        writefln("# chunks = %s", chunks.length);

        uint[M2Distance] uniq;
        uint total = 0;

        foreach(ch; chunks) {
            auto c2 = cast(M2Chunk)ch;
            if(!c2.root().isAir) {
                foreach(c; c2.root().cells) {
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
