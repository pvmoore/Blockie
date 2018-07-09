
#ifdef DEBUG

void printOctreeIndex(bool isOffset, global OctreeIndex* idx) {
    const global uchar* pchar = (global uchar*)idx;
    printf("OctreeIndex{\n");
    if(isOffset) {
        const uint offset = load3Bytes(pchar);
        printf("%u (offset)\n", offset);
    } else {
        printf("%u (value)\n", pchar[0]);
    }
    printf("}\n");
}

void printOctreeBranch(global OctreeBranch* br) {
    printf("OctreeBranch{\n");
    printf("  bits: %u\n",br->bits);
    printf("  indexes[8] {\n");
    for(int i=0; i<8; i++) {
        const bool isOffset = br->bits&(1<<i);
        const global void* p      = &br->indexes[i];
        const global uchar* pchar = p;
        if(isOffset) {
            const uint offset = load3Bytes(pchar);
            printf("    [%u] %u (offset)\n", i, offset);
        } else {
            printf("    [%u] %u (value)\n", i, pchar[0]);
        }
    }
    printf("}}\n");
}

#endif // DEBUG