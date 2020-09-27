
#line 1 3

/**
 *  Assumes numBits is between 1 and 32.
 */
uint getBits_voxelsIn(uint byteIndex, uint bitOffset, int numBits) {
    byteIndex += bitOffset/8;
    bitOffset &= 7u;
    const uint uintIndex = byteIndex/4;
    const uint uintRem   = byteIndex&3u;
    const int bitpos     = int(bitOffset + (uintRem*8));
    const int numBits2   = max(0, numBits - (32-bitpos));
    numBits -= numBits2;

    return bitfieldExtract(voxelsIn[uintIndex], bitpos, numBits) +
          (bitfieldExtract(voxelsIn[uintIndex+1], 0, numBits2) << numBits);
}

/// get 1 bit octet index (0-7)
uint getOctet_1_1(const uvec3 inXYZ) {
	// x = 0000_0001 \
	// y = 0000_0001  >  oct = 00000zyx
	// z = 0000_0001 /
	//const uvec3 a = inXYZ & 1u;
	const uvec3 a = bitfieldExtract(inXYZ, 0, 1);
	const uvec3 c = a << uvec3(0,1,2);
	return c.x + c.y + c.z;
}
/// get 1 bit octet index (0-7)
uint getOctet_1_2(const uvec3 inXYZ) {
	// x = 0000_0010 \
	// y = 0000_0010  >  oct = 00000zyx
	// z = 0000_0010 /
	const uvec3 a = bitfieldExtract(inXYZ, 1, 1);
	const uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
	//return a.x + (a.y<<1) + (a.z<<2);

	//const uvec3 a = inXYZ & 2u;
	//return (a.x>>1) + a.y + (a.z<<1);
	//const uvec3 a = (inXYZ >> 1) & 1u;
	//const uvec3 c = a << uvec3(0,1,2);
	//return c.x + c.y + c.z;
}
/// get 1 bit octet index (0-7)
uint getOctet_1_3(const uvec3 inXYZ) {
	// x = 0000_0100 \
	// y = 0000_0100  >  oct = 00000zyx
	// z = 0000_0100 /
	const uvec3 a = bitfieldExtract(inXYZ, 2, 1);
    const uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;
	//const uvec3 a = inXYZ & 4u;
	//return (a.x>>2) + (a.y>>1) + a.z;
}
/// get 1 bit octet index (0-7)
uint getOctet_1_n(const uvec3 inXYZ, const uint and) {
    // if and==32:
	// x = 0_0010_0000 \
	// y = 0_0010_0000  >  oct = 00000zyx
	// z = 0_0010_0000 /
	const int SHR = findLSB(and);
	const uvec3 a = bitfieldExtract(inXYZ, SHR, 1);
    const uvec3 c = a << uvec3(0,1,2);
    return c.x + c.y + c.z;

//	const uvec3 a  = (inXYZ >> SHR) & 1u;
//	const uvec3 c  = a << uvec3(0,1,2);
//	return c.x + c.y + c.z;
}

/// get 2 bit octet index (0-63)
//uint getOctetRoot_11(const uvec3 inXYZ) {
//#if CHUNK_SIZE==1024
//    // 11_00000000 -> 00_00zzyyxx
//    const uint and  = 3 << 8;
//    const uvec3 SHR = uvec3(8,6,4);
//#elif CHUNK_SIZE==512
//    // 01_10000000 -> 00_00zzyyxx
//    const uint and  = 3 << 7;
//    const uvec3 SHR = uvec3(7,5,3);
//#elif CHUNK_SIZE==256
//    // 00_11000000 -> 00_00zzyyxx
//    const uint and  = 3 << 6;
//    const uvec3 SHR = uvec3(6,4,2);
//#elif CHUNK_SIZE==128
//    // 00_01100000 -> 00_00zzyyxx
//    const uint and  = 3 << 5;
//    const uvec3 SHR = uvec3(5,3,1);
//#endif
//    const uvec3 b = (inXYZ & and) >> SHR;
//    return b.x + b.y + b.z;
//}

/// get 3 bit octet index (0-511)
//uint getOctetRoot_111(const uvec3 inXYZ) {
//#if CHUNK_SIZE==1024
//    // 11_10000000 -> 0z_zzyyyxxx
//    const uint and  = 7 << 7;
//    const uvec3 SHR = uvec3(7,4,1);
//    const uvec3 a   = inXYZ & and;
//    const uvec3 b   = a >> SHR;
//    return b.x + b.y + b.z;
//#elif CHUNK_SIZE==512
//    // 01_11000000 -> 0z_zzyyyxxx
//    const uvec3 a = bitfieldExtract(inXYZ, 6, 3);
//    const uvec3 c = a << uvec3(0,3,6);
//    return c.x + c.y + c.z;
////    const uint and  = 7 << 6;
////    const uvec3 SHR = uvec3(6,3,0);
////    const uvec3 a   = inXYZ & and;
////    const uvec3 b   = a >> SHR;
////    return b.x + b.y + b.z;
//#elif CHUNK_SIZE==256
//    // 00_11100000 -> 0z_zzyyyxxx
//    const uint and  = 7 << 5;
//    const uvec3 SHL = uvec3(0,0,1);
//    const uvec3 SHR = uvec3(5,2,0);
//    const uvec3 a   = inXYZ & and;
//    const uvec3 b   = (a << SHL) >> SHR;
//    return b.x + b.y + b.z;
//#else
//    return 0;
//#endif
//}

/// get 4 bit octet index (0-4095)
uint getOctetRoot_1111(const uvec3 inXYZ) {
    // 11_1100_0000 -> zzzz_yyyyxxxx
    const uvec3 a = bitfieldExtract(inXYZ, 6, 4);
    const uvec3 c = a << uvec3(0,4,8);
    return c.x + c.y + c.z;

//    const uint and  = 15 << 6;
//    const uvec3 SHL = uvec3(0,0,2);
//    const uvec3 SHR = uvec3(6,2,0);
//
//    const uvec3 a  = inXYZ & and;
//    const uvec3 b  = (a << SHL) >> SHR;
//    return b.x + b.y + b.z;

}
