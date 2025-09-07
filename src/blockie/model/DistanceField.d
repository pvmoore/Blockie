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
            DFieldBi(.maxOf(x.up, f.x.up), .maxOf(x.down, f.x.down)),
            DFieldBi(.maxOf(y.up, f.y.up), .maxOf(y.down, f.y.down)),
            DFieldBi(.maxOf(z.up, f.z.up), .maxOf(z.down, f.z.down))
        );
    }
    uint volume() {
        return x.length() * y.length() * z.length();
    }
    string toString() { return "[(%s),(%s),(%s)]".format(x, y, z); }
}
