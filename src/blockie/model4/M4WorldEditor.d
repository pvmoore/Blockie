module blockie.model4.M4WorldEditor;

import blockie.all;

final class M4WorldEditor : WorldEditor {
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

        uint[M4Distance] uniq;
        uint total = 0;

        foreach(ch; chunks) {
            auto c4 = cast(M4Chunk)ch;
            if(!c4.root().isAir) {
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