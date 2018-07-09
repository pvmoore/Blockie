
void checkStructs() {
    assert(__OPENCL_VERSION__,120);
    assert(__ENDIAN_LITTLE__,1);
    assert(__IMAGE_SUPPORT__,1);
    assert(__FAST_RELAXED_MATH__,1);

    assert(sizeof(ShadeConstants), 24);
    assert(sizeof(Chunk),4);
    assert(sizeof(Constants),132);
    assert(sizeof(Ray),64);
    assert(sizeof(BBox),32);
    assert(sizeof(Voxel),3);
    assert(sizeof(const global char*), 8);
    assert(sizeof(uint3), 16);
    assert(sizeof(Position),56);

    assert(sizeof(OctreeLeaf),8);
    assert(sizeof(OctreeIndex),3);
    assert(sizeof(OctreeBranch),25);

    #if OCTREE_ROOT_BITS==1
        assert(sizeof(OctreeRoot),26);
    #elif OCTREE_ROOT_BITS==2
        assert(sizeof(OctreeRoot),201);
    #elif OCTREE_ROOT_BITS==3
        assert(sizeof(OctreeRoot),1601);
    #elif OCTREE_ROOT_BITS==4
        assert(sizeof(OctreeRoot),12801);
    #elif OCTREE_ROOT_BITS==5
        assert(sizeof(OctreeRoot),102401);
    #endif
}

kernel void Init()
{
    int x   = get_global_id(0);
    int y   = get_global_id(1);
    int lx  = get_local_id(0);
    int ly  = get_local_id(1);

    if(x==0 && y==0) {
        checkStructs();
    }
}
