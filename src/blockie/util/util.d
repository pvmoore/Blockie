module blockie.util.util;

import blockie.globals;
import core.bitop : bsr;

//Pixel toPixel(vec3 v) pure nothrow @nogc{
//    return Pixel(min(v.x, 1.0f),
//                 min(v.y, 1.0f),
//                 min(v.z, 1.0f)
//    );
//}

uint bitsRequiredToEncode(ulong count) {
    if(count==0) return 0;
    if(count==1) return 0;  // implied
    return bsr(count-1)+1;
}

uint bitsRequiredToEncode2(ulong value) {
    return value<3 ? 1 : bsr(value-1)+1;
}

uint getImpliedIndex_32bit(uint bits, uint index) {
    assert(index < 32);
    uint and = 0x7fffffff >> (31-index);
    return popcnt(bits & and);
}
uint getImpliedIndex_64bit(ulong bits, uint index) {
    assert(index < 64);
    ulong and = 0x7fffffff_ffffffff >> (63-index);
    return popcnt(bits & and);
}

string toHexString(T)(T[] array) if(isInteger!T) {
    enum size = T.sizeof * 2;
    auto buf = appender!(string);
    foreach(i; 0..array.length) {
        if(i>0) buf ~= ", ";
        buf ~= mixin("\"%0" ~ size.to!string ~ "x\".format(array[i])");
    }
    return buf.data;
}

pragma(inline, true) void ASSERT(bool b, string file=__FILE__, int line=__LINE__) {
    // If we are in debug
    assert(b, "Woops %s:%s".format(file, line));

    version(RELEASE_ASSERT) {
        if(!b) throw new Error("Assertion failed");
    }
}

string getModelName() {
    /// Display world name
    version(MODEL1) return "1";
    else version(MODEL1a) return "1a";
    else version(MODEL2) return "2";
    else version(MODEL3) return "3";
    else version(MODEL4) return "4";
    else version(MODEL5) return "5";
    else version(MODEL6) return "6";
    else return "Unknown Model";
}
