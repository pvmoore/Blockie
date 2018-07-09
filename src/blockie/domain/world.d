module blockie.domain.world;

import blockie.all;

final class World {
    string name;
    string description;
    vec3 sunPos;
    Camera3D camera;

    override string toString() {
        return "World['%s']".format(name);
    }
    this(string name) {
        this.name = name;
    }
}

