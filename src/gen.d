module gen;

import blockie.all;
import blockie.generate.all;
import std.file : remove, dirEntries, SpanMode;

void main(string[] args) {

	Generator app;

    try{
        app = new Generator();
        app.run();
    }catch(Throwable t) {
        writefln("Error: %s", t.msg);
    }finally{
        writefln("");
        flushConsole();
    }
}

final class Generator {
    void run() {
        initEvents(1*MB);

        const auto num = "1";

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
            default: expect(false);
        }

        auto world = scene.getWorld();

        world.save();

        string dirName  = "data/" ~ world.name ~ "/";

        version(MODEL1) {
            foreach(string name; dirEntries(dirName, "M1*", SpanMode.shallow)) {
                remove(name);
            }
            generateModel1(scene, world);
        } else version(MODEL2) {
            foreach(string name; dirEntries(dirName, "M2*", SpanMode.shallow)) {
                remove(name);
            }
            generateModel2(scene, world);
        } else version(MODEL3) {
            foreach (string name; dirEntries(dirName, "M3*", SpanMode.shallow)) {
                remove(name);
            }
            generateModel3(scene, world);
        } else version(MODEL4) {
            foreach(string name; dirEntries(dirName, "M4*", SpanMode.shallow)) {
                remove(name);
            }
            generateModel4(scene, world);
        } else assert(false);

        writefln("\nFinished OK");
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
    void generateModel4(SceneGenerator sceneGenerator, World world) {
        writefln("\n=========================================");
        writefln("Generating Model4 %s", world);
        writefln("=========================================\n");

        auto editor = new M4WorldEditor(world, new Model4);
        scope(exit) editor.destroy();

        sceneGenerator.build(editor);

        //editor.startTransaction();
        //editor.setVoxel(worldcoords(0,0,0), 1);
        //editor.setVoxel(worldcoords(7,7,7), 1);
        //editor.commitTransaction();

        //writefln("testing...");
        //
        //uint3 p = uint3(
        //    63,
        //    63,
        //    63
        //);
        //uint3 b   = p << uint3(0,7,14);
        //uint cell = b.x | b.y | b.z;
        //writefln("pos  = %s", p);
        //writefln("bits = %07b, %07b, %07b", p.z, p.y, p.x);
        //writefln("cell = %s", cell);
        //
        //uint3 c = (p<<1) << uint3(0,6,12);
        //uint d = c.x | c.y | c.z;
        //writefln("d=%s", d);
        //
        //M4Root root;
        //root.setCellToNonAir(cell);
        //root.calculateLevel1To6Bits();
        //writefln("bits[1]=%08b", root.bits[0]);
        //
        //writef("bits[2]="); foreach(i; 4..12) writef("%08b ", root.bits[i]); writefln("");
        //writef("bits[3]="); foreach(i; 12..76) writef("%08b ", root.bits[i]); writefln("");

        //uint bit = root.bits[4 + ]
    }
}
