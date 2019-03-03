module blockie.model1.M1ChunkEditView;

import blockie.all;

final class M1ChunkEditView : ChunkEditView {
    M1Chunk chunk;
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
    override Chunk getChunk() {
        return chunk;
    }
    override chunkcoords pos() {
        return chunk.pos;
    }
    override void beginTransaction(Chunk chunk) {
        assert(chunk !is null);

        this.chunk = cast(M1Chunk)chunk;

        convertToEditable();
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
        expect(cell<M1_CELLS_PER_CHUNK);

        return root.isAirCell(cell);
    }
    override void setDistance(ubyte x, ubyte y, ubyte z) {
        root.flags.distX = x;
        root.flags.distY = y;
        root.flags.distZ = z;
    }
    override void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z) {
        expect(cell<M1_CELLS_PER_CHUNK);
        expect(isAirCell(cell));

        /// We only have 5 bits per axis (uni-directional)
        x = min(31, x).as!ubyte;
        y = min(31, y).as!ubyte;
        z = min(31, z).as!ubyte;

        root.cellDistances[cell].set(x,y,z);
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
        // todo - make this work for chunks that are not solid air

        this.version_ = chunk.getVersion();

        expect(chunk.isAir);

        root            = OctreeRoot();
        root.flags.flag = OctreeFlag.AIR;

        branches.length = 0;
        leaves.length   = 0;
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
                br.setOffset(oct, toIndex(leaf));

                leaf.setAllVoxels(oldValue);
            } else {
                // add branch node
                auto newBranch = getFreeBranch();
                br.setOffset(oct, toIndex(newBranch));

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
                br.setVoxel(oct, v);

                if(br.isSolid) {
                    freeBranches.push(toIndex(br));
                    collapse(nodes.pop(), octs.pop());
                }
            }
        }

        // octree root
        //static if(OCTREE_ROOT_BITS==1) {
        //    uint oct = getOctet_1(x,y,z, and);
        //} else static if(OCTREE_ROOT_BITS==2) {
        //    uint oct = getOctetRoot_11(x,y,z, CHUNK_SIZE_SHR);
        //} else static if(OCTREE_ROOT_BITS==3) {
        //    uint oct = getOctetRoot_111(x,y,z, CHUNK_SIZE_SHR);
        //} else static if(OCTREE_ROOT_BITS==4) {
        uint oct = getOctetRoot_1111(x,y,z, CHUNK_SIZE_SHR);
        //} else static if(OCTREE_ROOT_BITS==5) {
        //    uint oct = getOctetRoot_11111(x,y,z, CHUNK_SIZE_SHR);
        //} else static assert(false);

        auto root  = &root;
        auto index = &root.indexes[oct];

        if(root.isSolid(oct)) {
            //writefln("root isSolid");
            ubyte v2 = index.voxel;
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

            if(branch.isSolid(oct)) {
                //writefln("branch is solid");
                ubyte v2 = index.voxel;
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
        ubyte v2  = leaf.getVoxel(oct);
        // no change
        if(v2==v) return;
        // change the voxel
        leaf.setVoxel(oct, v);
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

