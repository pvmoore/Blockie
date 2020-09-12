module blockie.model.world;

import blockie.model;
import std.file  : mkdir, rmdirRecurse, write;
import std.stdio : File;

final class World {
    string name;
    string description;
    float3 sunPos;
    Camera3D camera;

    this(string name) {
        this.name = name;
    }

    static World load(string name) {
        World w = new World(name);

        string dirName  = "data/" ~ name ~ "/";
        string infoFile = dirName ~ "info.txt";

        scope f = File(infoFile, "r");
        string[string] lines;
        foreach(l; f.byLine) {
            l = l.strip();
            if(l.length>0 && l[0]!='#') {
                auto mid     = l.indexOf('=');
                string key   = l[0..mid].strip().dup;
                string value = l[mid+1..$].strip().dup;
                lines[key]   = value;
            }
        }
        float3 getFloat3(string s) {
            string[] tokens = s.split(",");
            return vec3(
                tokens[0].to!float,
                tokens[1].to!float,
                tokens[2].to!float
            );
        }
        w.description = lines["description"];
        w.sunPos      = getFloat3(lines["sun_position"]);

        version(VULKAN) {
            w.camera = Camera3D.forVulkan(
                getFloat3(lines["camera_position"]),
                getFloat3(lines["camera_focal_point"]) * float3(1,-1,-1)
            );
        } else {
            w.camera = new Camera3D(
                getFloat3(lines["camera_position"]),
                getFloat3(lines["camera_focal_point"])
            );
        }

        w.camera.fovNearFar(
            (lines["camera_fov"].to!float).degrees,
            lines["camera_near"].to!float,
            lines["camera_far"].to!float
        );

        writefln("sunPos=%s", w.sunPos);
        writefln("camera=%s", w.camera);
        return w;
    }
    void save() {
        string dirName  = "data/" ~ name ~ "/";
        string infoFile = dirName ~ "info.txt";

        if(!exists(dirName)) {
            mkdir(dirName);
        }

        auto cp = camera.position;
        auto fp = camera.focalPoint;
        auto sp = sunPos;

        write(infoFile,
            "description = \n" ~
            "camera_position = %s,%s,%s\n".format(cp.x,cp.y,cp.z) ~
            "camera_focal_point = %s,%s,%s\n".format(fp.x,fp.y,fp.z) ~
            "camera_fov = %s\n".format(camera.fov.degrees) ~
            "camera_near = %s\n".format(camera.near) ~
            "camera_far = %s\n".format(camera.far) ~
            "sun_position = %s,%s,%s\n".format(sp.x,sp.y,sp.z)
        );
    }

    override string toString() {
        return "World[\"%s\"]".format(name);
    }
}

