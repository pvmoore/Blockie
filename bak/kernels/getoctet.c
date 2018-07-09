#ifndef GETOCTET_C
#define GETOCTET_C

/// get 1 bit octet index (0-7)
inline uint getOctet_1(const uint3 inXYZ,
                       const uint and)
{
	// x = 1000_0000 \
	// y = 1000_0000  >  oct = 00000zyx
	// z = 1000_0000 /
	int3 xyz = (((inXYZ&and) == and) & 1) << (int3)(0,1,2);
	return xyz.x + xyz.y + xyz.z;
}

/// get 2 bit octet index (0-63)
inline uint getOctet_11(const uint3 inXYZ) {
#if CHUNK_SIZE==1024
    // 11_00000000 -> 00_00zzyyxx
    const uint3 SHR = (uint3)(8,6,4);
    const uint and = 3 << 8;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a >> SHR);
#elif CHUNK_SIZE==512
    // 01_10000000 -> 00_00zzyyxx
    const uint3 SHR = (uint3)(7,5,3);
    const uint and = 3 << 7;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a >> SHR);
#elif CHUNK_SIZE==256
    // 00_11000000 -> 00_00zzyyxx
    const uint3 SHR = (uint3)(6,4,2);
    const uint and = 3 << 6;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a >> SHR);
#elif CHUNK_SIZE==128
    // 00_01100000 -> 00_00zzyyxx
    const uint3 SHR = (uint3)(5,3,1);
    const uint and = 3 << 5;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a >> SHR);
#elif CHUNK_SIZE==64
    // 00_00110000 -> 00_00zzyyxx
    const uint3 SHR = (uint3)(4,2,0);
    const uint and = 3 << 4;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a >> SHR);
#endif
    return b.x + b.y + b.z;
}

/// get 3 bit octet index (0-511)
inline uint getOctet_111(const uint3 inXYZ) {
#if CHUNK_SIZE==1024
    // 11_10000000 -> 0z_zzyyyxxx
    const uint3 SHR = (uint3)(7,4,1);
    const uint and = 7 << 7;
    const uint3 a  = inXYZ & and;
    const uint3 b  = a >> SHR;
#elif CHUNK_SIZE==512
    // 01_11000000 -> 0z_zzyyyxxx
    const uint3 SHR = (uint3)(6,3,0);
    const uint and = 7 << 6;
    const uint3 a  = inXYZ & and;
    const uint3 b  = a >> SHR;
#elif CHUNK_SIZE==256
    // 00_11100000 -> 0z_zzyyyxxx
    const uint3 SHL = (uint3)(0,0,1);
    const uint3 SHR = (uint3)(5,2,0);
    const uint and = 7 << 5;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#elif CHUNK_SIZE==128
    // 00_01110000 -> 0z_zzyyyxxx
    const uint3 SHL = (uint3)(0,0,2);
    const uint3 SHR = (uint3)(4,1,0);
    const uint and = 7 << 4;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#elif CHUNK_SIZE==64
    // 00_00111000 -> 0z_zzyyyxxx
    const uint3 SHL = (uint3)(0,0,3);
    const uint3 SHR = (uint3)(3,0,0);
    const uint and = 7 << 3;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#endif
    return b.x + b.y + b.z;
}

/// get 4 bit octet index (0-4095)
inline uint getOctet_1111(const uint3 inXYZ) {
#if CHUNK_SIZE==1024
    // 0011_11000000 -> zzzz_yyyyxxxx
    const uint3 SHL = (uint3)(0,0,2);
    const uint3 SHR = (uint3)(6,2,0);
    const uint and = 15 << 6;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#elif CHUNK_SIZE==512
    // 0001_11100000 -> zzzz_yyyyxxxx
    const uint3 SHL = (uint3)(0,0,3);
    const uint3 SHR = (uint3)(5,1,0);
    const uint and = 15 << 5;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#elif CHUNK_SIZE==256
    // 0000_11110000 -> zzzz_yyyyxxxx
    const uint3 SHL = (uint3)(0,0,4);
    const uint3 SHR = (uint3)(4,0,0);
    const uint and = 15 << 4;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#elif CHUNK_SIZE==128
    // 0000_01111000 -> zzzz_yyyyxxxx
    const uint3 SHL = (uint3)(0,1,5);
    const uint3 SHR = (uint3)(3,0,0);
    const uint and = 15 << 3;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#elif CHUNK_SIZE==64
    // 0000_00111100 -> zzzz_yyyyxxxx
    const uint3 SHL = (uint3)(0,2,6);
    const uint3 SHR = (uint3)(2,0,0);
    const uint and = 15 << 2;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#endif
    return b.x + b.y + b.z;
}

/// get 5 bit octet index (0-32767)
inline uint getOctet_11111(const uint3 inXYZ) {
#if CHUNK_SIZE==1024
    // 11_11100000 -> 0zzzzzyy_yyyxxxxx
    const uint3 SHL = (uint3)(0,0,5);
    const uint3 SHR = (uint3)(5,0,0);
    const uint and = 31 << 5;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#elif CHUNK_SIZE==512
    // 01_11110000 -> 0zzzzzyy_yyyxxxxx
    const uint3 SHL = (uint3)(0,1,6);
    const uint3 SHR = (uint3)(4,0,0);
    const uint and = 31 << 4;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#elif CHUNK_SIZE==256
    // 00_11111000 -> 0zzzzzyy_yyyxxxxx
    const uint3 SHL = (uint3)(0,2,7);
    const uint3 SHR = (uint3)(3,0,0);
    const uint and = 31 << 3;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#elif CHUNK_SIZE==128
    // 00_01111100 -> 0zzzzzyy_yyyxxxxx
    const uint3 SHL = (uint3)(0,3,8);
    const uint3 SHR = (uint3)(2,0,0);
    const uint and = 31 << 2;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#elif CHUNK_SIZE==64
    // 00_00111110 -> 0zzzzzyy_yyyxxxxx
    const uint3 SHL = (uint3)(0,4,9);
    const uint3 SHR = (uint3)(1,0,0);
    const uint and = 31 << 1;
    const uint3 a  = inXYZ & and;
    const uint3 b  = (a << SHL) >> SHR;
#endif
    return b.x + b.y + b.z;
}
#endif // GETOCTET_C