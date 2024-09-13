module blockie.model1.M1ChunkEditView;

import blockie.model;

/**
 * CHUNK_SIZE_SHR=10 and OCTREE_ROOT_BITS=4:
 * 11_1100_0000  cell
 *      10_0000  branch
 *       1_0000  branch
 *         1000  branch
 *          100  branch
 *           10  leaf
 *            1  voxel index
 */
align(1):

struct OctreeRoot { static assert(OctreeRoot.sizeof ==
                                    OctreeFlags.sizeof +
                                    512 +
                                    OctreeIndex.sizeof*4096 +
                                    Distance3.sizeof*M1_CELLS_PER_CHUNK); 
align(1):
    OctreeFlags flags;                              /// 8 bytes
    ubyte[M1_CELLS_PER_CHUNK/8] bits;               /// 512 bytes (4096/8)
    OctreeIndex[M1_CELLS_PER_CHUNK] indexes;        /// 4096 * 3 bytes
    Distance3[M1_CELLS_PER_CHUNK] cellDistances;    /// 4096 * 3 bytes


    bool isAirCell(uint cell) {
        ASSERT(cell<M1_CELLS_PER_CHUNK);
        return isSolidCell(cell) && getVoxel(cell)==0;
    }
    bool isSolidCell(uint cell) {
        ASSERT(cell<M1_CELLS_PER_CHUNK);
        return getBit(cell)==0;
    }

    uint numOffsets() {
        uint count = 0;
        foreach(b; bits) count += popcnt(b);
        return count;
    }
    bool getBit(uint cell) {
        ASSERT(cell<M1_CELLS_PER_CHUNK);
        const byteIndex = cell>>3;
        const bitIndex  = cell&7;
        return (bits[byteIndex] & (1<<bitIndex)) !=0;
    }
    void setBit(uint cell, bool value) {
        ASSERT(cell<M1_CELLS_PER_CHUNK);
        const byteIndex = cell>>3;
        const bitIndex  = cell&7;

        if(value) {
            bits[byteIndex] |= cast(ubyte)(1<<bitIndex);
        } else {
            bits[byteIndex] &= cast(ubyte)~(1<<bitIndex);
        }
    }
    ubyte getVoxel(uint cell) {
        ASSERT(cell<M1_CELLS_PER_CHUNK);
        return indexes[cell].getVoxel();
    }
    void setVoxel(uint cell, ubyte v) {
        ASSERT(cell<M1_CELLS_PER_CHUNK);
        // set to solid voxel
        setBit(cell, false);
        indexes[cell].setVoxel(v);
    }
    uint getOffset(uint cell) {
        ASSERT(cell<M1_CELLS_PER_CHUNK);
        return indexes[cell].offset;
    }
    void setOffset(uint cell, uint offset) {
        ASSERT(cell<M1_CELLS_PER_CHUNK);
        // set to index
        setBit(cell, true);
        indexes[cell].offset = offset;
    }
    bool bitsIsZero() {
        return isZeroMem(bits.ptr, bits.length);
    }

    bool isSolid() {
        if(!bitsIsZero()) return false;
        ubyte v = indexes[0].getVoxel();
        return onlyContains(indexes.ptr, indexes.length*OctreeIndex.sizeof, v);
    }
    bool isSolidAir() {
        return flags.flag==OctreeFlag.AIR;
    }
    void setToSolid(ubyte v) {
        bits[] = 0;
        foreach(ref i; indexes) {
            i.setVoxel(v);
        }
    }
    void recalculateFlags() {
        if(indexes[0].getVoxel()==V_AIR && bitsIsZero() && isSolid()) {
            flags.flag = OctreeFlag.AIR;
        } else {
            flags.flag = OctreeFlag.MIXED;
        }
    }
}
struct OctreeBranch { static assert(OctreeBranch.sizeof==25); align(1):
    ubyte bits;
    OctreeIndex[8] indexes;

    uint numOffsets() {
        return popcnt(bits);
    }
    bool isSolid() {
        if(bits!=0) return false;
        ubyte v = getVoxelAt(0);
        for(auto i=1;i<8;i++) if(indexes[i].getVoxel()!=v) return false;
        return true;
    }
    void setToSolid(ubyte v) {
        bits = 0;
        foreach(ref i; indexes) {
            i.setVoxel(v);
        }
    }

    ubyte getVoxelAt(uint oct) {
        ASSERT(oct<8);
        return indexes[oct].getVoxel();
    }
    void setVoxelAt(uint oct, ubyte v) {
        ASSERT(oct<8);
        bits &= cast(ubyte)~(1<<oct);
        indexes[oct].setVoxel(v);
    }
    // uint getOffsetAt(uint oct) {
    //     ASSERT(oct<8);
    //     return indexes[oct].offset;
    // }
    void setOffsetAt(uint oct, uint offset) {
        ASSERT(oct<8);
        bits |= cast(ubyte)(1<<oct);
        indexes[oct].offset = offset;
    }
    bool isSolidAt(uint oct) {
        return 0==(bits & (1<<oct));
    }

}
struct OctreeIndex { static assert(OctreeIndex.sizeof==3); align(1):
    ubyte[3] v;

    ubyte getVoxel() {
        return v[0];
    }
    void setVoxel(ubyte voxel) {
        v[0] = voxel;
        v[1] = 0;
        v[2] = OctreeFlag.NONE;
    }
    uint offset() {
        return (v[2]<<16) | (v[1]<<8) | v[0];
    }
    void offset(uint o) {
        v[0] = cast(ubyte)(o&0xff);
        v[1] = cast(ubyte)(o>>8)&0xff;
        v[2] = cast(ubyte)(o>>16)&0xff;
    }
}
struct OctreeLeaf { static assert(OctreeLeaf.sizeof==8); align(1):
    ubyte[8] voxels;

    bool isSolid() {
        ubyte v = getVoxelAt(0);
        for(auto i=1; i<voxels.length; i++) {
            if(getVoxelAt(i)!=v) return false;
        }
        return true;
    }
    ubyte getVoxelAt(uint oct) {
        ASSERT(oct<8);
        return voxels[oct];
    }
    void setVoxelAt(uint oct, ubyte v) {
        ASSERT(oct<8);
        voxels[oct] = v;
    }
    void setAllVoxelsTo(ubyte v) {
        voxels[] = v;
    }
}

//==========================================================================================

final class M1ChunkEditView : ChunkEditView {
    OctreeRoot root;
    OctreeBranch[] branches;
    OctreeBranch[] l2Branches;
    OctreeLeaf[] leaves;
    Stack!uint freeLeaves;
    Stack!uint freeBranches;

    uint version_;
    M1Optimiser optimiser;

    this() {
        this.freeLeaves   = new Stack!uint(8);
        this.freeBranches = new Stack!uint(8);
        this.branches.assumeSafeAppend();
        this.leaves.assumeSafeAppend();
        this.optimiser    = new M1Optimiser(this);
    }

    override void beginTransaction(Chunk chunk) {
        super.beginTransaction(chunk);

        convertToEditable();
    }
    override void voxelEditsCompleted() {
        root.recalculateFlags();
    }
    override void commitTransaction() {

        auto optVoxels = optimiser.optimise();

        /// Write voxels back to chunk
        uint ver = chunk.atomicUpdate(version_, optVoxels);
        if(ver!=version_+1) {
            /// Stale
            log("M2ChunkEditView: %s is stale", chunk);
        } else {
            log("Chunk %s updated to version %s", chunk, ver);
        }
    }
    override void setVoxel(uint3 offset, ubyte value) {
        setOctreeVoxel(value, offset.x, offset.y, offset.z);
    }
    override bool isAir() {
        return root.flags.flag==OctreeFlag.AIR;
    }
    override bool isAirCell(uint cell) {
        ASSERT(cell<M1_CELLS_PER_CHUNK);

        return root.isAirCell(cell);
    }
    override void setChunkDistance(DFieldsBi f) {
        root.flags.distance.set(f);
    }
    override void setCellDistance(uint cell, uint x, uint y, uint z) {
        ASSERT(cell<M1_CELLS_PER_CHUNK);
        ASSERT(isAirCell(cell));

        /// We only have 5 bits per axis (uni-directional)
        x = min(31, x);
        y = min(31, y);
        z = min(31, z);

        root.cellDistances[cell].set(x.as!ubyte, y.as!ubyte, z.as!ubyte);
    }
    override void setCellDistance(uint cell, DFieldsBi df) {
        throw new Error("Not implemented");
    }


    ulong voxelsLength() const {
        return OctreeRoot.sizeof +
               OctreeBranch.sizeof*branches.length +
               OctreeLeaf.sizeof*leaves.length;
    }
    OctreeBranch* toBranchPtr(uint i) {
        return branches.ptr+i;
    }
    OctreeBranch* toL2BranchPtr(uint i) {
        return l2Branches.ptr+i;
    }
    OctreeLeaf* toLeafPtr(uint i) {
        return leaves.ptr+i;
    }
    uint toIndex(OctreeBranch* br) const {
        return cast(uint)(cast(ptrdiff_t)br - cast(ptrdiff_t)branches.ptr) / OctreeBranch.sizeof;
    }
    uint toIndex(OctreeLeaf* lf) const {
        return cast(uint)(cast(ptrdiff_t)lf - cast(ptrdiff_t)leaves.ptr) / OctreeLeaf.sizeof;
    }
    override string toString() {
        return "EditView for " ~ (chunk ? chunk.toString() : "[NULL chunk]");
    }
private:
    void convertToEditable() {
        
        immutable(ubyte)[] originalVoxels;
        chunk.atomicGet(this.version_, originalVoxels);

        // todo - make this work for chunks that are not solid air
        throwIfNot(chunk.isAir);

        root            = OctreeRoot();
        root.flags.flag = OctreeFlag.AIR;

        branches.length = 0;
        leaves.length   = 0;
    }
    /// get 4 bit octet index (0-4095)
    uint getOctet_11_1100_0000(uint X,
                               uint Y,
                               uint Z)
    {
        uint and = 0b11_1100_0000;
        uint x   = X & and;
        uint y   = Y & and;
        uint z   = Z & and;

        // 11_1100_0000 -> zzzz_yyyyxxxx
        return (x>>>6) | (y>>>2) | (z<<2);
    }
    /// get 1 bit octet index (0-7)
    uint getOctet_1(uint X,
                    uint Y,
                    uint Z,
                    uint and)
    {
        // x = 1000_0000 \
        // y = 1000_0000  >  oct = 0000_0zyx
        // z = 1000_0000 /
        uint x = (X & and) == and;
        uint y = (Y & and) == and;
        uint z = (Z & and) == and;
        return x | (y << 1) | (z << 2);
    }
    void setOctreeVoxel(ubyte v, uint x, uint y, uint z) {
        //writefln("setOctreeVoxel(%s, %s,%s,%s)", v, x,y,z);

        /// We can't be air any more
        if(v!=0) root.flags.flag = OctreeFlag.MIXED;

        // ensure branches and leaves have enough capacity for this update
        if(branches.capacity < branches.length + 16) {
            branches.reserve(branches.length + 5_000);
        }
        if(leaves.capacity < leaves.length + 16) {
            leaves.reserve(leaves.length + 1_000);
        }

        uint and = CHUNK_SIZE >>> 1;

        // thread locals
        static Stack!(OctreeBranch*) nodes;
        static Stack!uint octs;
        if(!nodes) {
            nodes  = new Stack!(OctreeBranch*)(CHUNK_SIZE_SHR);
            octs   = new Stack!uint(CHUNK_SIZE_SHR);
        } else {
            nodes.clear();
            octs.clear();
        }

        OctreeBranch* getFreeBranch() {
            if(!freeBranches.empty) {
                return toBranchPtr(freeBranches.pop());
            }
            uint i = cast(uint)branches.length;
            branches.length += 1;
            if(branches.length >= 2^^24) throw new Error("Max num branches reached");
            return toBranchPtr(i);
        }
        OctreeLeaf* getFreeLeaf() {
            if(!freeLeaves.empty) {
                return toLeafPtr(freeLeaves.pop());
            }
            uint i = cast(uint)leaves.length;
            leaves.length += 1;
            if(leaves.length >= 2^^24) throw new Error("Max num leaves reached");
            return toLeafPtr(i);
        }
        void expandRoot(OctreeRoot* rt, uint oct, ubyte oldValue)  {
            //writefln("expandRoot(%s,%s)",oct,oldValue);
            // add branch node
            auto branch = getFreeBranch();
            rt.setOffset(oct, toIndex(branch));
            branch.setToSolid(oldValue);
        }
        void expandBranch(OctreeBranch* br, uint oct, ubyte oldValue)  {
            //writefln("expandBranch(%s,%s,%s)",branchToIndex(br), oct,oldValue);

            bool isParentOfLeaf() { return and==2; }

            if(isParentOfLeaf()) {
                // add leaf node
                auto leaf = getFreeLeaf();
                br.setOffsetAt(oct, toIndex(leaf));

                leaf.setAllVoxelsTo(oldValue);
            } else {
                // add branch node
                auto newBranch = getFreeBranch();
                br.setOffsetAt(oct, toIndex(newBranch));

                newBranch.setToSolid(oldValue);
            }
        }
        void collapse(OctreeBranch* br, uint oct)  {
            //writefln("collapse(%s,%s) nodes.length=%s", toUint(br),oct, nodes.length);

            bool isRoot = cast(OctreeRoot*)br is &root;

            if(isRoot) {
                //writefln("  this is a root");
                auto root = cast(OctreeRoot*)br;
                root.setVoxel(oct, v);
            } else {
                // branch
                br.setVoxelAt(oct, v);

                if(br.isSolid) {
                    freeBranches.push(toIndex(br));
                    collapse(nodes.pop(), octs.pop());
                }
            }
        }

        // octree root
        uint oct = getOctet_11_1100_0000(x,y,z);

        auto root  = &this.root;
        auto index = &root.indexes[oct];

        if(root.isSolidCell(oct)) {
            //writefln("root isSolid");
            ubyte v2 = index.getVoxel();
            // if it's the same then we are done
            if(v2==v) return;
            // it is different so expand downwards
            expandRoot(root, oct, v2);
        }
        nodes.push(cast(OctreeBranch*)root);
        octs.push(oct);

        // octree branches
        auto branch = toBranchPtr(index.offset);
        and >>= M1_OCTREE_ROOT_BITS;
        // if view_SIZE==512 and OCTREE_ROOT_BITS==3 then
        // and = 0_0010_0000

        //writefln("branch = %s %s", index.offset, branch);

        // octree branches
        while(and>1) {
            oct   = getOctet_1(x,y,z,and);
            index = &branch.indexes[oct];

            if(branch.isSolidAt(oct)) {
                //writefln("branch is solid");
                ubyte v2 = index.getVoxel();
                // if it's the same then we are done
                if(v2==v) return;
                // it is different so expand downwards
                expandBranch(branch, oct, v2);
            }
            nodes.push(branch);
            octs.push(oct);
            branch = toBranchPtr(index.offset);
            and >>= 1;
        }
        // octree leaf
        oct = getOctet_1(x,y,z, 1);
        //writefln("leaf oct = %s", oct);
        //writefln("leaf index = %s", index.offset);
        auto leaf = toLeafPtr(index.offset);//cast(OctreeLeaf*)branch;
        ubyte v2  = leaf.getVoxelAt(oct);
        // no change
        if(v2==v) return;
        // change the voxel
        leaf.setVoxelAt(oct, v);
        if(leaf.isSolid) {
            //writefln("leaf is solid");

            // this leaf is now solid so optimise it away
            //logNodes(ptr, nodes);
            freeLeaves.push(toIndex(leaf));
            collapse(nodes.pop(), octs.pop());
        }
        //dumpNodes(nodes);
        //dump(root);
        //dump(&branches[0]);
        //    writefln("%s branches", branches.length);
        //    writefln("%s leaves", leaves.length);
        //    writefln("freeBranches = %s", freeBranches);
        //    writefln("freeLeaves = %s", freeLeaves);
        //    foreach(i, b; branches) {
        //        writefln("branch %s", i);
        //        dump(&b);
        //    }
    }
    //void dumpNodes(Stack!(OctreeBranch*) st)  {
    //    writefln("nodes (bottom to top) (%s nodes):", st.length);
    //
    //    for(auto i=0; i<st.length; i++) {
    //        auto index = st.peek(i);
    //        writefln("  [%s] %s", i, index);
    //    }
    //}

    //void dump(OctreeLeaf* l) {
    //    writef("LEAF %s", l.voxels);
    //}
    //void dump(OctreeBranch* b) {
    //    writefln("BRANCH bits=%s", b.bits);
    //    writefln("{");
    //    foreach(oct, idx; b.indexes) {
    //        if(b.isSolid(cast(uint)oct)) {
    //            writefln("  [%s] solid %s", oct, idx.voxel);
    //        } else {
    //            writefln("  [%s] offset %s", oct, idx.offset);
    //        }
    //    }
    //    writefln("}");
    //}
    //void dump(OctreeRoot* b) {
    //    writefln("ROOT %s %s", b.flags.flag, b.bits);
    //    writefln("{");
    //    foreach(oct, idx; b.indexes) {
    //        if(b.isSolid(cast(uint)oct)) {
    //            writefln("  [%s] solid %s", oct, idx.voxel);
    //        } else {
    //            writefln("  [%s] offset %s", oct, idx.offset);
    //        }
    //    }
    //    writefln("}");
    //}
}

