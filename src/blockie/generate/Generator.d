module blockie.generate.Generator;

import blockie.generate.all;

import std.file : remove, exists, dirEntries, SpanMode;

final class Generator {
    void run() {
        initEvents(1*1024*1024);

        setEagerFlushing(true);

        const auto num = "9"; // "6";

        float f = 0;
        if(f<1) {
            // testing();
            // return;
        }

        SceneGenerator scene;
        switch(num) {
            case "1" : scene = new TestScene1; break;
            case "2" : scene = new TestScene2; break;
            case "3" : scene = new TestScene3; break;
            case "4" : scene = new TestScene4; break;
            case "4b": scene = new TestScene4b; break;
            case "4c": scene = new TestScene4c; break;
            case "5" : scene = new TestScene5; break;
            case "6" : scene = new TestScene6_bunny; break;
            case "7" : scene = new TestScene7_hgt; break;
            case "8" : scene = new TestScene8; break;
            case "9" : scene = new TestScene9; break;
            default: throwIf(true); break;
        }

        auto world = scene.getWorld();

        world.save();

        string dirName  = "data/" ~ world.name ~ "/";

        version(MODEL1) {
            removeFile(dirName ~ "M1.chunks.zip");
            generateModel1(scene, world);
        } else version(MODEL1A) {
            removeFile(dirName ~ "M1A.chunks.zip");
            generateModel1A(scene, world);
        } else version(MODEL2) {
            removeFile(dirName ~ "M2.chunks.zip");
            generateModel2(scene, world);
        } else version(MODEL3) {
            version(MODEL_B) {
                removeFile(dirName ~ "M3b.chunks.zip");
            } else {
                removeFile(dirName ~ "M3.chunks.zip");
            }
            generateModel3(scene, world);
        } else version(MODEL4) {
            removeFile(dirName ~ "M4.chunks.zip");
            generateModel4(scene, world);
        } else version(MODEL5) {
            removeFile(dirName ~ "M5.chunks.zip");
            generateModel5(scene, world);
        } else version(MODEL6) {
            removeFile(dirName ~ "M6.chunks.zip");
            generateModel6(scene, world);
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
    // void generateModel1A(SceneGenerator sceneGenerator, World world) {
    //     writefln("\n=========================================");
    //     writefln("Generating MODEL1A %s", world);
    //     writefln("=========================================\n");

    //     auto editor = new M1aWorldEditor(world, new Model1a);
    //     scope(exit) editor.destroy();

    //     // editor.startTransaction();
    //     // editor.setVoxel(worldcoords(0,0,0), 1);
    //     // editor.setVoxel(worldcoords(1,0,0), 1);
    //     // editor.setVoxel(worldcoords(0,1,0), 1);
    //     // editor.setVoxel(worldcoords(1,1,0), 1);
    //     // editor.setVoxel(worldcoords(2,0,0), 1);
    //     // editor.commitTransaction();

    //     sceneGenerator.build(editor);
    // }
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
    void generateModel4(SceneGenerator sceneGenerator, World world) {
        writefln("\n=========================================");
        writefln("Generating Model4 %s", world);
        writefln("=========================================\n");

        auto editor = new M4WorldEditor(world, new Model4);
        scope(exit) editor.destroy();

        sceneGenerator.build(editor);
    }
    void generateModel5(SceneGenerator sceneGenerator, World world) {
        writefln("\n=========================================");
        writefln("Generating Model5 %s", world);
        writefln("=========================================\n");

        auto editor = new M5WorldEditor(world, new Model5);
        scope(exit) editor.destroy();

        sceneGenerator.build(editor);

        // editor.startTransaction();
        // editor.setVoxel(worldcoords(0,0,0), 1);
        // editor.setVoxel(worldcoords(7,7,7), 1);
        // editor.commitTransaction();
    }
    void generateModel6(SceneGenerator sceneGenerator, World world) {
        writefln("\n=========================================");
        writefln("Generating Model6 %s", world);
        writefln("=========================================\n");

        auto editor = new M6WorldEditor(world, new Model6);
        scope(exit) editor.destroy();

        // editor.startTransaction();
        // editor.setVoxel(worldcoords(0,0,0), 1);
        // editor.setVoxel(worldcoords(31,0,0), 1);
        // editor.setVoxel(worldcoords(32,0,0), 1);


        //editor.setVoxel(worldcoords(0,1,0), 1);


        //editor.setVoxel(worldcoords(0,0,1), 1);


        //editor.setVoxel(worldcoords(31,31,31), 1);

        //editor.commitTransaction();

        sceneGenerator.build(editor);
    }
}
