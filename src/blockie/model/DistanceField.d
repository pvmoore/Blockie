module blockie.model.DistanceField;

import blockie.model;

struct DFieldBi {
    int up, down;

    uint length() {
        return (up+down) + 1;
    }
    bool canContain(DFieldBi f) const {
        return up >= f.up && down >= f.down;
    }
    string toString() { return "%s..%s".format(up, down); }
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
    uint volume() {
        return x.length() * y.length() * z.length();
    }
    string toString() { return "[(%s),(%s),(%s)]".format(x, y, z); }
}
