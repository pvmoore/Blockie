module blockie.util.util;

import blockie.all;
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
