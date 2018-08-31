module blockie.util.util;

import blockie.all;

//Pixel toPixel(vec3 v) pure nothrow @nogc{
//    return Pixel(min(v.x, 1.0f),
//                 min(v.y, 1.0f),
//                 min(v.z, 1.0f)
//    );
//}

uint bitsRequiredToEncode(ulong count) {
    import core.bitop : bsr;

    if(count==0) return 0;
    if(count==1) return 0;  // implied
    return bsr(count-1)+1;
}
