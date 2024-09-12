module blockie.util;

import blockie.globals;
import core.bitop : bsr;

//Pixel toPixel(vec3 v) pure nothrow @nogc{
//    return Pixel(min(v.x, 1.0f),
//                 min(v.y, 1.0f),
//                 min(v.z, 1.0f)
//    );
//}

string toHexString(T)(T[] array) if(isInteger!T) {
    enum size = T.sizeof * 2;
    auto buf = appender!(string);
    foreach(i; 0..array.length) {
        if(i>0) buf ~= ", ";
        buf ~= mixin("\"%0" ~ size.to!string ~ "x\".format(array[i])");
    }
    return buf.data;
}

/**
 * Align byte array to multiple of 4 by adding zeroes if necessary
 */
void alignToUint(ref ubyte[] bytes) {
    auto rem = bytes.length&3;
    if(rem==0) return;

    foreach(i; 0..4-rem) {
        bytes ~= 0.as!ubyte;
    }
}

uint bitsRequiredToEncode(ulong count) {
    return count<2 ? 0 : bsr(count-1)+1;
}

uint bitsRequiredToEncode2(ulong count) {
    return count<3 ? 1 : bsr(count-1)+1;
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

pragma(inline, true) void ASSERT(bool b, string file=__FILE__, int line=__LINE__) {
    // If we are in debug
    assert(b, "Woops %s:%s".format(file, line));

    version(RELEASE_ASSERT) {
        if(!b) throw new Error("Assertion failed");
    }
}
