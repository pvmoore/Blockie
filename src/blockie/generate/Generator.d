module blockie.generate.Generator;

import blockie.generate.all;

import std.file : remove, exists, dirEntries, SpanMode;

final class Generator {
    void run() {
        initEvents(1*1024*1024);

        setEagerFlushing(true);

        float f = 0;
        if(f<1) {
            // testing();
            // return;
        }

        SceneGenerator scene;
        switch(cast(uint)(SCENE*10)) {
            case 10  : scene = new TestScene1; break;
            case 20  : scene = new TestScene2; break;
            case 30  : scene = new TestScene3; break;
            case 40  : scene = new TestScene4; break;
            case 410 : scene = new TestScene4b; break;
            case 420 : scene = new TestScene4c; break;
            case 50  : scene = new TestScene5; break;
            case 60  : scene = new TestScene6_bunny; break;
            case 70  : scene = new TestScene7_hgt; break;
            case 80  : scene = new TestScene8; break;
            case 90  : scene = new TestScene9; break;
            default: throwIf(true); break;
        }

        auto world = scene.getWorld();

        world.save();

        string dirName  = "data/" ~ world.name ~ "/";

        static if(MODEL==1) {
            removeFile(dirName ~ "M1.chunks.zip");
            generateModel1(scene, world);
        } else static if(MODEL==2) {
            removeFile(dirName ~ "M2.chunks.zip");
            generateModel2(scene, world);
        } else static if(MODEL==3) {
            removeFile(dirName ~ "M3.chunks.zip");
            generateModel3(scene, world);
        } else assert(false);

        writefln("\nFinished OK");
    }
    void removeFile(string filename) {
        if(exists(filename)) remove(filename);
    }
    void generateModel1(SceneGenerator sceneGenerator, World world) {
        writefln("\n=========================================");
        writefln("Generating Model1 %s", world);
        writefln("=========================================\n");

        auto editor = new M1WorldEditor(world, new Model1);
        scope(exit) editor.destroy();

        sceneGenerator.build(editor);
    }
    void generateModel2(SceneGenerator sceneGenerator, World world) {
        writefln("\nGenerating Model2 %s", world);

        auto editor = new M2WorldEditor(world, new Model2);
        scope(exit) editor.destroy();

        sceneGenerator.build(editor);

        //editor.startTransaction();
        //editor.setVoxel(worldcoords(0,0,0), 1);
        //editor.setVoxel(worldcoords(1,0,0), 1);
        //editor.setVoxel(worldcoords(0,1,0), 1);
        //editor.setVoxel(worldcoords(1,1,0), 1);
        //
        //editor.setVoxel(worldcoords(0,0,1), 1);
        //editor.setVoxel(worldcoords(1,0,1), 1);
        //editor.setVoxel(worldcoords(0,1,1), 1);
        //editor.setVoxel(worldcoords(1,1,1), 1);
        //
        //editor.setVoxel(worldcoords(2,0,0), 1);
        //editor.setVoxel(worldcoords(2,2,0), 1);
        //
        //editor.setVoxel(worldcoords(64,0,0), 1);

        //editor.setVoxelBlock(worldcoords(0,0,0), 2, 1);
        //editor.commitTransaction();
    }
    void generateModel3(SceneGenerator sceneGenerator, World world) {
        writefln("\nGenerating Model3 %s", world);

        auto editor = new M3WorldEditor(world, new Model3);
        scope(exit) editor.destroy();

        sceneGenerator.build(editor);
    }
}
