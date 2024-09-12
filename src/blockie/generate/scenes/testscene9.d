module blockie.generate.scenes.testscene9;

import blockie.generate.all;

final class TestScene9 : SceneGenerator {
public:
    this() {
        //this.model = new MagicaVoxelModel("/temp/voxel_models/horse.vox");
        //this.model = new MagicaVoxelModel("/temp/voxel_models/deer.vox");
        //this.model = new MagicaVoxelModel("/temp/voxel_models/chr_knight.vox");
        //this.model = new MagicaVoxelModel("/temp/voxel_models/monu0.vox");

        this.model = new MagicaVoxelModel("/temp/voxel_models/monu10.vox");
    }
    @Implements("WorldGen")
    World getWorld() {
        World w = new World("Test Scene 9");

        w.sunPos = vec3(512, 1024*10, 1024);

        w.camera = new Camera3D(
            vec3(1200,1100,1000),   // position
            vec3(0,0,0)             // focal point
        );
        w.camera.fovNearFar(60.degrees, 10, 100000);
        return w;
    }
    @Implements("WorldGen")
    void build(WorldEditor edit) {
        edit.startTransaction();

        model.write(edit);

        edit.commitTransaction();
    }
private:
    MagicaVoxelModel model;
}
