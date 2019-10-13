module blockie.model.DistanceField;

import blockie.all;

struct DFieldBi {
    int up, down;

    bool canContain(DFieldBi f) {
        return up >= f.up && down >= f.down;
    }
    string toString() { return "%s-%s".format(up, down); }
}

struct DFieldsBi {
    DFieldBi x,y,z;

    DFieldsBi max(DFieldsBi f) {
        return DFieldsBi(
            DFieldBi(.max(x.up, f.x.up), .max(x.down, f.x.down)),
            DFieldBi(.max(y.up, f.y.up), .max(y.down, f.y.down)),
            DFieldBi(.max(z.up, f.z.up), .max(z.down, f.z.down))
        );
    }
    string toString() { return "[(%s),(%s),(%s)]".format(x, y, z); }
}
