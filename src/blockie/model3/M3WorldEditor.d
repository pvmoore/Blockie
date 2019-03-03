module blockie.model3.M3WorldEditor;

import blockie.all;

final class M3WorldEditor : WorldEditor {
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

        uint[M3Distance] uniq;
        uint total = 0;

        foreach(ch; chunks) {
            auto c3 = cast(M3Chunk)ch;
            if(!c3.root().isAir) {
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