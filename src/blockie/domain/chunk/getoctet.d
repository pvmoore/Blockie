module blockie.domain.chunk.getoctet;

import blockie.all;
import core.bitop : bsf;

/// get 1 bit octet index (0-7)
pragma(inline,true)
uint getOctet_1(const uint X,
                const uint Y,
                const uint Z,
                const uint and) nothrow
{
    // x = 1000_0000 \
    // y = 1000_0000  >  oct = 00000zyx
    // z = 1000_0000 /
    const uint x = (X & and) == and;
    const uint y = (Y & and) == and;
    const uint z = (Z & and) == and;
    return x | (y << 1) | (z << 2);
}
/// get 1 bit octet index (0-7)
//pragma(inline,true)
//uint getOctet_11(const uint X,
//                 const uint Y,
//                 const uint Z,
//                 const uint and) nothrow
//{
//    // x = 0011_0000 \
//    // y = 0011_0000  >  oct = 00zzyyxx
//    // z = 0011_0000 /
//    const uint SHR = bsf(and);
//    const uint x = (X >> SHR) & 3;
//    const uint y = (Y >> SHR) & 3;
//    const uint z = (Z >> SHR) & 3;
//    return x | (y << 2) | (z << 4);
//}
//------------------------------------------------------------------

/// get 2 bit octet index (0-63)
uint getOctetRoot_11(const uint X,
                     const uint Y,
                     const uint Z,
                     uint level) nothrow
{
    const uint and = 0b11 << (level-2);
    const uint x   = X & and;
    const uint y   = Y & and;
    const uint z   = Z & and;

    switch(level) {
    case 6:
        // 00000000_00110000 -> 00000000_00zzyyxx
        return (x>>>4) | (y>>>2) | z;
    case 7:
        // 00000000_01100000 -> 00000000_00zzyyxx
        return (x>>>5) | (y>>>3) | (z>>>1);
    case 8:
        // 00000000_11000000 -> 00000000_00zzyyxx
        return (x>>>6) | (y>>>4) | (z>>>2);
    case 9:
        // 00000001_10000000 -> 00000000_00zzyyxx
        return (x>>>7) | (y>>>5) | (z>>>3);
    case 10:
        // 00000011_00000000 -> 00000000_00zzyyxx
        return (x>>>8) | (y>>>6) | (z>>>4);
    default:
        assert(false);
    }
}
//------------------------------------------------------------------

/// get 3 bit octet index (0-511)
uint getOctetRoot_111(const uint X,
                      const uint Y,
                      const uint Z,
                      uint level) nothrow
{
    const uint and = 0b111 << (level-3);
    const uint x   = X & and;
    const uint y   = Y & and;
    const uint z   = Z & and;

    switch(level) {
    case 6:
        // 00000000_00111000 -> 0000000z_zzyyyxxx
        return (x>>>3) | y | (z<<3);
    case 7:
        // 00000000_01110000 -> 0000000z_zzyyyxxx
        return (x>>>4) | (y>>>1) | (z<<2);
    case 8:
        // 00000000_11100000 -> 0000000z_zzyyyxxx
        return (x>>>5) | (y>>>2) | (z<<1);
    case 9:
        // 00000001_11000000 -> 0000000z_zzyyyxxx
        return (x>>>6) | (y>>>3) | z;
    case 10:
        // 00000011_10000000 -> 0000000z_zzyyyxxx
        return (x>>>7) | (y>>>4) | (z>>>1);
    default:
        assert(false);
    }
}
//------------------------------------------------------------------

/// get 4 bit octet index (0-4095)
pragma(inline,true)
uint getOctetRoot_1111(const uint X,
                       const uint Y,
                       const uint Z,
                       uint level) nothrow
{
    const uint and = 0b1111 << (level-4);
    const uint x   = X & and;
    const uint y   = Y & and;
    const uint z   = Z & and;

    switch(level) {
    case 6:
        // 00000000_00111100 -> 0000zzzz_yyyyxxxx
        return (x>>>2) | (y<<2) | (z<<6);
    case 7:
        // 00000000_01111000 -> 0000zzzz_yyyyxxxx
        return (x>>>3) | (y<<1) | (z<<5);
    case 8:
        // 00000000_11110000 -> 0000zzzz_yyyyxxxx
        return (x>>>4) | y | (z<<4);
    case 9:
        // 00000001_11100000 -> 0000zzzz_yyyyxxxx
        return (x>>>5) | (y>>>1) | (z<<3);
    case 10:
        // 00000011_11000000 -> 0000zzzz_yyyyxxxx
        return (x>>>6) | (y>>>2) | (z<<2);
    default:
        assert(false);
    }
}
//------------------------------------------------------------------

/// get 5 bit octet index (0-32767)
pragma(inline,true)
uint getOctetRoot_11111(const uint X,
                        const uint Y,
                        const uint Z,
                        uint level) nothrow
{
    const uint and = 0b1_1111 << (level-5);
    const uint x   = X & and;
    const uint y   = Y & and;
    const uint z   = Z & and;

    switch(level) {
    case 6:
        // 00000000_00111110 -> 0zzzzzyy_yyyxxxxx
        return (x>>>1) | (y<<4) | (z<<9);
    case 7:
        // 00000000_01111100 -> 0zzzzzyy_yyyxxxxx
        return (x>>>2) | (y<<3) | (z<<8);
    case 8:
        // 00000000_11111000 -> 0zzzzzyy_yyyxxxxx
        return (x>>>3) | (y<<2) | (z<<7);
    case 9:
        // 00000001_11110000 -> 0zzzzzyy_yyyxxxxx
        return (x>>>4) | (y<<1) | (z<<6);
    case 10:
        // 00000011_11100000 -> 0zzzzzyy_yyyxxxxx
        return (x>>>5) | y | (z<<5);
    default:
        assert(false);
    }
}