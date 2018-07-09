module blockie.domain.load_save;
/**
 *
 */
import blockie.all;
import std.file  : dirEntries, exists, isDir,
                   mkdir, remove, rmdirRecurse, write;
import std.stdio : File;

private final struct ChunkHeader {
    uint version_;
}

/**
 *  Load a chunk and return the number of bytes read.
 *  This function sets the Chunk updated voxels ready for it
 *  to be activated.
 */
ulong loadChunk(World w, Chunk c) {
    string filename = "data/" ~ w.name ~ "/" ~ c.filename;

    if(!exists(filename)) {
        // Chunk is air.
        // This should never happen
        // todo - this needs to be versioned in some way
        return 0;
    }
    scope f = File(filename, "rb");
    auto fileSize = f.size();

    ChunkHeader[1] header;
    f.rawRead(header);

    c.voxels.length = fileSize - ChunkHeader.sizeof;

    c.version_ = header[0].version_;
    f.rawRead(c.voxels);

    return fileSize;
}
/**
 *  Saves a Chunk and returns the number of bytes written.
 */
ulong saveChunk(World w, Chunk c) {
    string filename = "data/" ~ w.name ~ "/" ~ c.filename;

    if(c.isAir()) {
        // todo - this needs to be versioned in some way
        if(exists(filename)) {
            remove(filename);
        }
        return 0;
    }

    scope f = File(filename, "wb");

    ChunkHeader header;
    header.version_ = c.version_;

    f.rawWrite([header]);
    f.rawWrite(c.voxels);

    return ChunkHeader.sizeof + c.voxels.length;
}
/**
 *  Load a World from data/name/ directory.
 */
World loadWorld(string name) {
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
    vec3 getVector3(string s) {
        string[] tokens = s.split(",");
        return vec3(
            tokens[0].to!float,
            tokens[1].to!float,
            tokens[2].to!float
        );
    }
    w.description = lines["description"];
    w.sunPos      = getVector3(lines["sun_position"]);
    w.camera = new Camera3D(
        getVector3(lines["camera_position"]),
        getVector3(lines["camera_focal_point"])
    );
    w.camera.fovNearFar(
        (lines["camera_fov"].to!float).degrees,
        lines["camera_near"].to!float,
        lines["camera_far"].to!float
    );

    writefln("sunPos=%s", w.sunPos);
    writefln("camera=%s", w.camera);
    return w;
}
/**
 *  Save a World.
 */
void saveWorld(World w) {
    string dirName  = "data/" ~ w.name ~ "/";
    string infoFile = dirName ~ "info.txt";

    if(exists(dirName)) {
        rmdirRecurse(dirName);
    }
    mkdir(dirName);

    auto cp = w.camera.position;
    auto fp = w.camera.focalPoint;
    auto sp = w.sunPos;

    write(infoFile,
        "description = \n" ~
        "camera_position = %s,%s,%s\n".format(cp.x,cp.y,cp.z) ~
        "camera_focal_point = %s,%s,%s\n".format(fp.x,fp.y,fp.z) ~
        "camera_fov = %s\n".format(w.camera.fov.degrees) ~
        "camera_near = %s\n".format(w.camera.near) ~
        "camera_far = %s\n".format(w.camera.far) ~
        "sun_position = %s,%s,%s\n".format(sp.x,sp.y,sp.z)
    );
}
AirChunk[] loadAirChunks(World w) {
    string filename = "data/" ~ w.name ~ "/air-chunks.dat";
    if(!exists(filename)) return null;
    scope f = File(filename, "rb");
    if(f.size==0) return null;
    AirChunk[] data = new AirChunk[f.size/AirChunk.sizeof];
    f.rawRead(data);
    return data;
}
void saveAirChunks(World w, AirChunk[] data) {
    //foreach(ref c; data) writefln("%s", c);
    string filename = "data/" ~ w.name ~ "/air-chunks.dat";
    scope f = File(filename, "wb");
    f.rawWrite(data);
}