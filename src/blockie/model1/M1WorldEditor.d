module blockie.model1.M1WorldEditor;

import blockie.all;

final class M1WorldEditor : WorldEditor {
protected:
    override void generateDistances() {
        new ChunkDistanceFields(storage, chunks)
            .generate();

        new CellDistanceFields(chunks, model)
            .generate();
    }
public:
    this(World world, Model model) {
        super(world, model);
    }
}