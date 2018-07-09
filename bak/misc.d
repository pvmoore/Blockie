/// x,y,z is voxel coords within the chunk.
void setSparseVoxel(Chunk chunk, ubyte v,
                    uint x, uint y, uint z) nothrow
{
    uint oct    = getFirstOctree(x,y,z);
    uint offset = oct*BRANCH_NODE_SIZE;

    // assumes 3bit subchunk size
    uint and    = 1 << (CHUNK_SIZE_SHR-4);
    ubyte bits;

    // This is not thead safe !!
    static Stack!uint nodes;
    static Stack!uint octs;
    if(!nodes) {
        nodes  = new Stack!uint(CHUNK_SIZE_SHR);
        octs   = new Stack!uint(CHUNK_SIZE_SHR);
    } else {
        nodes.clear();
        octs.clear();
    }

    pragma(inline, true)
    ubyte getVoxel(uint i) nothrow {
        return chunk.sparseVoxels[i];
    }
    pragma(inline, true)
    void setVoxel(uint i, ubyte value) nothrow {
        chunk.sparseVoxels[i] = value;
    }
    pragma(inline, true)
    bool isSolid() nothrow {
        return 0==(bits & (1<<oct));
    }
    pragma(inline, true)
    uint getNextFreeNode() nothrow {
        uint nextFreeNode = cast(uint)chunk.sparseVoxels.length;
        if(and==2) {
            if(!chunk.freeLeaves.empty) return chunk.freeLeaves.pop();
            chunk.sparseVoxels.length += LEAF_NODE_SIZE;
        } else {
            if(!chunk.freeBranches.empty) return chunk.freeBranches.pop();
            chunk.sparseVoxels.length += BRANCH_NODE_SIZE;
        }
        return nextFreeNode;
    }
    pragma(inline, true)
    void setOffset(uint i, uint o) nothrow {
        setVoxel(i+0, cast(ubyte)(o&0xff));
        setVoxel(i+1, cast(ubyte)(o>>8)&0xff);
        setVoxel(i+2, cast(ubyte)(o>>16)&0xff);
    }
    pragma(inline, true)
    void setToSparse(uint i, ubyte oldValue) nothrow {
        // set bit
        setVoxel(offset, getVoxel(offset) | cast(ubyte)(1<<oct));
        // set offset of lower node
        uint nodeOffset = getNextFreeNode();
        setOffset(i, nodeOffset);

        if(and==2) {
            // add leaf node
            for(auto j=0;j<8;j++) {
                setVoxel(nodeOffset+j, oldValue);
            }
        } else {
            // add branch node
            // bits
            setVoxel(nodeOffset, 0);
            nodeOffset++;
            // values
            for(auto j=0;j<8;j++) {
                setVoxel(nodeOffset+0+j*3, oldValue);
                setVoxel(nodeOffset+1+j*3, 0);
                setVoxel(nodeOffset+2+j*3, 0);
            }
        }
    }
    pragma(inline, true)
    void freeBranch(uint nodeOffset, uint nodeOct) nothrow {
        bool isSolidBranch() nothrow {
            if(getVoxel(nodeOffset)!=0) return false;
            for(auto j=0;j<8;j++) if(getVoxel(nodeOffset+1+j*3)!=v) return false;
            return true;
        }
        // bits
        setVoxel(nodeOffset, getVoxel(nodeOffset) & ~cast(ubyte)(1<<nodeOct));
        // voxel values
        setVoxel(nodeOffset + 1 + nodeOct*3, v);
        setVoxel(nodeOffset + 2 + nodeOct*3, 0);
        setVoxel(nodeOffset + 3 + nodeOct*3, 0);

        if(nodeOffset >= 512*25 && isSolidBranch()) {
            chunk.freeBranches.push(nodeOffset);
            uint nodeOffset2 = nodes.pop();
            nodeOct          = octs.pop();
            freeBranch(nodeOffset2, nodeOct);
        }
    }
    pragma(inline, true)
    void freeLeaf(uint nodeOffset, uint nodeOct) nothrow {
        bool isSolidLeaf() nothrow {
            for(auto j=0;j<8;j++) if(getVoxel(nodeOffset+j)!=v) return false;
            return true;
        }
        if(isSolidLeaf()) {
            chunk.freeLeaves.push(nodeOffset);
            freeBranch(nodes.pop(), octs.pop());
        }
    }

    while(true) {
        oct = getOctree(x,y,z,and);

        nodes.push(offset);
        octs.push(oct);

        if(and==1) {
            setVoxel(offset + oct, v);
            // free this leaf if it is now solid
            freeLeaf(nodes.pop(), octs.pop());
            return;
        }
        bits = getVoxel(offset);

        uint offsetPtr = offset + 1 + oct*INDEX_NUM_BYTES;

        if(isSolid()) {
            ubyte v2 = getVoxel(offsetPtr);
            // if it's the same then we are done
            if(v2==v) return;
            // it is different so expand downwards
            setToSparse(offsetPtr, v2);
        }
        // continue down
        uint* p = cast(uint*)(chunk.sparseVoxels.ptr+offsetPtr);
        offset  = (*p) & 0xffffff;

        and >>= 1;
    }
    assert(false);
}