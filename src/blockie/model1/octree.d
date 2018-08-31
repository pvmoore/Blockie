module blockie.model1.octree;

import blockie.all;
import core.bitop : popcnt;

/**
 *  y    z
 *  |   /----------
 *  |  /  2 /  3 /
 *  | /----------
 *  |/  0 /  1 /
 *  |----------x
 */

enum OctreeFlag : ubyte {
    NONE  = 0,
    AIR   = 1,
    MIXED = 2
}
align(1) final struct OctreeFlags { align(1):
    OctreeFlag flag;
    ubyte distX;
    ubyte distY;
    ubyte distZ;
}
static assert(OctreeFlags.sizeof==4);

//static if(OCTREE_ROOT_BITS==1) {
//    static assert(OctreeRoot.sizeof==OctreeFlags.sizeof+1+OctreeIndex.sizeof*8);
//} else static if(OCTREE_ROOT_BITS==2) {
//    static assert(OctreeRoot.sizeof==OctreeFlags.sizeof+8+OctreeIndex.sizeof*64);
//} else static if(OCTREE_ROOT_BITS==3) {
//    static assert(OctreeRoot.sizeof==OctreeFlags.sizeof+64+OctreeIndex.sizeof*512);
//} else static if(OCTREE_ROOT_BITS==4) {
    static assert(OctreeRoot.sizeof==OctreeFlags.sizeof+512+OctreeIndex.sizeof*4096); // 12804
//} else static if(OCTREE_ROOT_BITS==5) {
//    static assert(OctreeRoot.sizeof==OctreeFlags.sizeof+4096+OctreeIndex.sizeof*32768);
//} else static assert(false);

const uint OCTREE_ROOT_BITS_LENGTH    = 8^^(OCTREE_ROOT_BITS-1);    /// 512
const uint OCTREE_ROOT_INDEXES_LENGTH = 8^^OCTREE_ROOT_BITS;        /// 4096

final struct OctreeRoot {
    OctreeFlags flags;
    ubyte[OCTREE_ROOT_BITS_LENGTH] bits;
    OctreeIndex[OCTREE_ROOT_INDEXES_LENGTH] indexes;

    uint numOffsets() {
        uint count = 0;
        foreach(b; bits) count += popcnt(b);
        return count;
    }
    bool getBit(uint i) {
        static if(bits.length==1) {
            return (bits[0] & (1<<i)) !=0;
        } else {
            const byteIndex = i>>3;
            const bitIndex  = i&7;
            return (bits[byteIndex] & (1<<bitIndex)) !=0;
        }
    }
    void setBit(uint i, bool value) {
        static if(bits.length==1) {
            const byteIndex = 0;
            const bitIndex  = i;
        } else {
            const byteIndex = i>>3;
            const bitIndex  = i&7;
        }
        if(value) {
            bits[byteIndex] |= cast(ubyte)(1<<bitIndex);
        } else {
            //bits[byteIndex] &= ~cast(ubyte)(1<<bitIndex);
            bits[byteIndex] &= cast(ubyte)~(1<<bitIndex);
        }
    }
    ubyte getVoxel(uint oct) {
        return indexes[oct].voxel;
    }
    void setVoxel(uint oct, ubyte v) {
        // set to solid voxel
        setBit(oct, false);
        indexes[oct].set(v);
    }
    uint getOffset(uint oct) {
        return indexes[oct].offset;
    }
    void setOffset(uint oct, uint offset) {
        // set to index
        setBit(oct, true);
        indexes[oct].offset = offset;
    }
    bool bitsIsZero() {
        static if(bits.length==1) {
            return bits[0]==0;
        } else static if(bits.length==8) {
            return (cast(ulong*)bits.ptr)[0]==0;
        } else {
            return isZeroMem(bits.ptr, bits.length);
        }
    }
    bool isSolid(uint oct) {
        return getBit(oct)==0;
    }
    bool isSolid() {
        if(!bitsIsZero()) return false;
        ubyte v = indexes[0].voxel;
        return onlyContains(indexes.ptr, indexes.length*OctreeIndex.sizeof, v);
    }
    bool isSolidAir() {
        return flags.flag==OctreeFlag.AIR;
    }
    void setToSolid(ubyte v) {
        bits[] = 0;
        foreach(ref i; indexes) {
            i.set(v);
        }
    }
    void recalculateFlags() {
        if(indexes[0].voxel==V_AIR && bitsIsZero() && isSolid()) {
            flags.flag = OctreeFlag.AIR;
        } else {
            flags.flag = OctreeFlag.MIXED;
        }
    }
}
// ----------------------------------------------------------
static assert(OctreeTwig.sizeof==12);
final struct OctreeTwig {
    ubyte bits;
    ubyte[3] baseIndex;
    ubyte[8] voxels;

    uint getBaseIndex() {
        return (baseIndex[2]<<16) | (baseIndex[1]<<8) | baseIndex[0];
    }
    void setBaseIndex(uint b) {
        baseIndex[0] = cast(ubyte)(b&0xff);
        baseIndex[1] = cast(ubyte)(b>>8)&0xff;
        baseIndex[2] = cast(ubyte)(b>>16)&0xff;
    }
}
// ----------------------------------------------------------
static assert(OctreeBranch.sizeof==25);
final struct OctreeBranch {
    ubyte bits;
    OctreeIndex[8] indexes;

    uint numOffsets() {
        return popcnt(bits);
    }
    ubyte getVoxel(uint oct) {
        return indexes[oct].voxel;
    }
    void setVoxel(uint oct, ubyte v) {
        //bits &= ~cast(ubyte)(1<<oct);
        bits &= cast(ubyte)~(1<<oct);
        indexes[oct].set(v);
    }
    uint getOffset(uint oct) {
        return indexes[oct].offset;
    }
    void setOffset(uint oct, uint offset) {
        bits |= cast(ubyte)(1<<oct);
        indexes[oct].offset = offset;
    }
    bool isSolid() {
        if(bits!=0) return false;
        ubyte v = getVoxel(0);
        for(auto i=1;i<8;i++) if(indexes[i].voxel!=v) return false;
        return true;
    }
    bool isSolid(uint oct) {
        return 0==(bits & (1<<oct));
    }
    void setToSolid(ubyte v) {
        bits = 0;
        foreach(ref i; indexes) {
            i.set(v);
        }
    }
}
// ----------------------------------------------------------
static assert(OctreeLeaf.sizeof==8);
final struct OctreeLeaf {
    ubyte[8] voxels;

    ubyte getVoxel(uint oct) {
        return voxels[oct];
    }
    bool isSolid() {
        ubyte v = getVoxel(0);
        for(auto i=1; i<voxels.length; i++) {
            if(getVoxel(i)!=v) return false;
        }
        return true;
    }
    void setVoxel(uint oct, ubyte v) {
        voxels[oct] = v;
    }
    void setAllVoxels(ubyte v) {
        voxels[] = v;
    }
}
// ----------------------------------------------------------
static assert(OctreeIndex.sizeof==3);
final struct OctreeIndex {
    ubyte[3] v;

    ubyte voxel() {
        return v[0];
    }
    void set(ubyte voxel) {
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
// ----------------------------------------------------------
// todo - update me
/*ubyte getOctreeVoxel(const view view,
                     const uint X,
                     const uint Y,
                     const uint Z) 
{
    const ptr   = view.voxels.ptr;
    auto root   = cast(OctreeRoot*)ptr;
    uint and    = view_SIZE >> 1;

    // get root
    static if(OCTREE_ROOT_BITS==1) {
        uint oct = getOctet_1(X,Y,Z, and);
    } else static if(OCTREE_ROOT_BITS==2) {
        uint oct = getOctetRoot_11(X,Y,Z, view_SIZE_SHR);
    } else static if(OCTREE_ROOT_BITS==3) {
        uint oct = getOctetRoot_111(X,Y,Z, view_SIZE_SHR);
    } else static if(OCTREE_ROOT_BITS==4) {
        uint oct = getOctetRoot_1111(X,Y,Z, view_SIZE_SHR);
    } else static if(OCTREE_ROOT_BITS==5) {
        uint oct = getOctetRoot_11111(X,Y,Z, view_SIZE_SHR);
    } else static assert(false);

    OctreeIndex* index = &root.indexes[oct];
    if(root.isSolid(oct)) {
        return index.voxel;
    }

    // get branches
    auto branch = cast(OctreeBranch*)(ptr+index.offset);
    and >>= OCTREE_ROOT_BITS;

    while(and>1) {
        oct   = getOctet_1(X,Y,Z, and);
        index = &branch.indexes[oct];

        if(branch.isSolid(oct)) {
            return index.voxel;
        }
        branch = cast(OctreeBranch*)(ptr+index.offset);
        and >>= 1;
    }
    // get leaf
    oct = getOctet_1(X,Y,Z, 1);
    auto leaf = cast(OctreeLeaf*)branch;
    return leaf.getVoxel(oct);
}*/
// ------------------------------------------------------------------
/*void setOctreeVoxelOld(view view, ubyte v, uint x, uint y, uint z) { //
    setOctreeVoxel(
        view.voxels,
        view.freeLeaves,
        view.freeBranches,
        view.freeTrunks,
        v, x,y,z
    );
}
private void setOctreeVoxel(
    ref ubyte[] voxels,
    Stack!uint freeLeaves,
    Stack!uint freeBranches,
    Stack!uint freeTrunks,
    ubyte v,
    uint x, uint y, uint z) //
{
    //writefln("setOctreeVoxel(%s, %s,%s,%s)", v, x,y,z);
    uint and = view_SIZE >>> 1;

    // ensure view.voxels has enough
    // space to expand into if necessary
    auto maxExpansion = OctreeTrunk.sizeof+view_SIZE_SHR*OctreeBranch.sizeof;
    if(voxels.length+maxExpansion >= voxels.capacity) {
        // reserve another 200KB
        voxels.reserve(voxels.length + 1024*50);
    }
    auto voxelsPtr = voxels.ptr;
    auto length = voxels.length;

    // thread locals
    static Stack!(OctreeBranch*) nodes;
    static Stack!uint octs;
    if(!nodes) {
        nodes  = new Stack!(OctreeBranch*)(view_SIZE_SHR);
        octs   = new Stack!uint(view_SIZE_SHR);
    } else {
        nodes.clear();
        octs.clear();
    }

    pragma(inline,true) {
        ubyte* ptr() {
            if(voxelsPtr !is voxels.ptr) throw new Error("voxels realloced!! old length=%s, voxels.length=%s,  freeBranches=%s".format(length, voxels.length, freeBranches.length));
            return voxels.ptr;
        }
        OctreeTrunk* toTrunk(ulong i)  {
            return cast(OctreeTrunk*)(ptr+i);
        }
        OctreeBranch* toBranch(ulong i)  {
            return cast(OctreeBranch*)(ptr+i);
        }
        OctreeLeaf* toLeaf(ulong i)  {
            return cast(OctreeLeaf*)(ptr+i);
        }
        uint toUint(void* p)  {
            return cast(uint)(cast(ubyte*)p-ptr);
        }
        OctreeTrunk* getFreeTrunk()  {
            if(!freeTrunks.empty) {
                return toTrunk(freeTrunks.pop());
            }
            if(voxels.length>16777216-100) throw new Error("Voxels length exceeds 16MB");
            auto b = toTrunk(voxels.length);
            voxels.length += OctreeTrunk.sizeof;
            return b;
        }
        OctreeBranch* getFreeBranch()  {
            if(!freeBranches.empty) {
                return toBranch(freeBranches.pop());
            }
            if(voxels.length>16777216-100) throw new Error("Voxels length exceeds 16MB");
            auto b = toBranch(voxels.length);
            voxels.length += OctreeBranch.sizeof;
            return b;
        }
        OctreeLeaf* getFreeLeaf()  {
            if(!freeLeaves.empty) {
                return toLeaf(freeLeaves.pop());
            }
            if(voxels.length>16777216-100) throw new Error("Voxels length exceeds 16MB");
            auto l = toLeaf(voxels.length);
            voxels.length += OctreeLeaf.sizeof;
            return l;
        }
        void expandRoot(OctreeRoot* rt, uint oct, ubyte oldValue)  {
            //writefln("expandRoot(%s,%s)",oct,oldValue);
            // add branch node
            auto newTrunk = getFreeTrunk();
            rt.setOffset(oct, toUint(newTrunk));

            newTrunk.setToSolid(oldValue);
        }
        void expandTrunk(OctreeTrunk* tr, uint oct, ubyte oldValue)  {
            //writefln("expandTrunk(%s,%s)",oct,oldValue);
            // add branch node
            auto newBranch = getFreeBranch();
            tr.setOffset(oct, toUint(newBranch));

            newBranch.setToSolid(oldValue);
        }
        void expandBranch(OctreeBranch* br, uint oct, ubyte oldValue)  {
            //writefln("expandBranch(%s,%s)",oct,oldValue);

            bool isParentOfLeaf() { return and==2; }

            if(isParentOfLeaf()) {
                // add leaf node
                auto leaf = getFreeLeaf();
                br.setOffset(oct, toUint(leaf));

                leaf.setAllVoxels(oldValue);
            } else {
                // add branch node
                auto newBranch = getFreeBranch();
                br.setOffset(oct, toUint(newBranch));

                newBranch.setToSolid(oldValue);
            }
        }
        void collapse(OctreeBranch* br, uint oct)  {
            //writefln("collapse(%s,%s) nodes.length=%s", toUint(br),oct, nodes.length);

            bool isRoot() { return cast(void*)br is ptr; }
            bool isTrunk() { return nodes.length==1; }

            if(isRoot()) {
                //writefln("  this is a root");
                auto root = cast(OctreeRoot*)br;
                root.setVoxel(oct, v);
            } else if(isTrunk()) {
                //writefln("  this is a trunk");
                auto trunk = cast(OctreeTrunk*)br;
                trunk.setVoxel(oct, v);

                if(trunk.isSolid) {
                    freeTrunks.push(toUint(trunk));
                    auto parent = nodes.pop();
                    if(cast(ubyte*)parent !is voxels.ptr) throw new Error("wowzer");
                    collapse(parent, octs.pop());
                }
            } else {
                // branch
                br.setVoxel(oct, v);

                if(br.isSolid) {
                    freeBranches.push(toUint(br));
                    collapse(nodes.pop(), octs.pop());
                }
            }
        }
    }
    // octree root
    static if(OCTREE_ROOT_BITS==1) {
        uint oct = getOctet_1(x,y,z, and);
    } else static if(OCTREE_ROOT_BITS==2) {
        uint oct = getOctetRoot_11(x,y,z, view_SIZE_SHR);
    } else static if(OCTREE_ROOT_BITS==3) {
        uint oct = getOctetRoot_111(x,y,z, view_SIZE_SHR);
    } else static if(OCTREE_ROOT_BITS==4) {
        uint oct = getOctetRoot_1111(x,y,z, view_SIZE_SHR);
    } else static if(OCTREE_ROOT_BITS==5) {
        uint oct = getOctetRoot_11111(x,y,z, view_SIZE_SHR);
    } else static assert(false);

    auto root  = cast(OctreeRoot*)ptr;
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

    //dump(root);

    // octree trunk
    auto trunk = toTrunk(index.offset);
    and >>= OCTREE_ROOT_BITS;
    // if view_SIZE==512 and OCTREE_ROOT_BITS==3 then
    // and = 0_0010_0000

static if(OCTREE_TRUNK_BITS==1) {
    oct   = getOctet_1(x,y,z, and);  // 0_0010_0000
} else {
    oct   = getOctet_11(x,y,z, and | (and>>1));  // 0_0011_0000
}
    index = &trunk.indexes[oct];

    if(trunk.isSolid(oct)) {
        //writefln("trunk is solid");
        ubyte v2 = index.voxel;
        // if it's the same then we are done
        if(v2==v) return;
        // it is different so expand downwards
        expandTrunk(trunk, oct, v2);
    }
    nodes.push(cast(OctreeBranch*)trunk);
    octs.push(oct);

    // octree branches
    auto branch = toBranch(index.offset);
    and >>= OCTREE_TRUNK_BITS;
    // if view_SIZE==512 and OCTREE_ROOT_BITS==3 and TRUNK_BITS==2 then
    // and = 0_0000_1000

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
        branch = toBranch(index.offset);
        and >>= 1;
    }
    // octree leaf
    oct = getOctet_1(x,y,z, 1);
    //writefln("leaf oct = %s", oct);
    auto leaf = cast(OctreeLeaf*)branch;
    ubyte v2  = leaf.getVoxel(oct);
    // no change
    if(v2==v) return;
    // change the voxel
    leaf.setVoxel(oct, v);
    if(leaf.isSolid) {
        //writefln("leaf is solid");

        // this leaf is now solid so optimise it away
        //logNodes(ptr, nodes);
        freeLeaves.push(toUint(leaf));
        collapse(nodes.pop(), octs.pop());
    }
//    dumpNodes(ptr, nodes);
//    dump(root);
//    writefln("freeTrunks = %s", freeTrunks);
//    writefln("freeBranches = %s", freeBranches);
//    writefln("freeLeaves = %s", freeLeaves);
}
*/

//void dumpNodes(Stack!(OctreeBranch*) st)  {
//    writefln("nodes (bottom to top) (%s nodes):", st.length);
//
//    for(auto i=0; i<st.length; i++) {
//        auto index = st.peek(i);
//        writefln("  [%s] %s", i, index);
//    }
//}

void dump(OctreeLeaf* l) {
    writef("LEAF %s", l.voxels);
}
void dump(OctreeBranch* b) {
    writefln("BRANCH bits=%s", b.bits);
    writefln("{");
    foreach(oct, idx; b.indexes) {
        if(b.isSolid(cast(uint)oct)) {
            writefln("  [%s] solid %s", oct, idx.voxel);
        } else {
            writefln("  [%s] offset %s", oct, idx.offset);
        }
    }
    writefln("}");
}
void dump(OctreeRoot* b) {
    writefln("ROOT %s %s", b.flags.flag, b.bits);
    writefln("{");
    foreach(oct, idx; b.indexes) {
        if(b.isSolid(cast(uint)oct)) {
            writefln("  [%s] solid %s", oct, idx.voxel);
        } else {
            writefln("  [%s] offset %s", oct, idx.offset);
        }
    }
    writefln("}");
}

void setOctreeVoxel(M1ChunkEditView view, ubyte v, uint x, uint y, uint z) {
    //writefln("setOctreeVoxel(%s, %s,%s,%s)", v, x,y,z);

    // ensure branches and leaves have enough capacity for this update
    if(view.branches.capacity < view.branches.length + 16) {
        view.branches.reserve(view.branches.length + 5_000);
    }
    if(view.leaves.capacity < view.leaves.length + 16) {
        view.leaves.reserve(view.leaves.length + 1_000);
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
        if(!view.freeBranches.empty) {
            return view.toBranchPtr(view.freeBranches.pop());
        }
        uint i = cast(uint)view.branches.length;
        view.branches.length += 1;
        if(view.branches.length >= 2^^24) throw new Error("Max num branches reached");
        return view.toBranchPtr(i);
    }
    OctreeLeaf* getFreeLeaf() {
        if(!view.freeLeaves.empty) {
            return view.toLeafPtr(view.freeLeaves.pop());
        }
        uint i = cast(uint)view.leaves.length;
        view.leaves.length += 1;
        if(view.leaves.length >= 2^^24) throw new Error("Max num leaves reached");
        return view.toLeafPtr(i);
    }
    void expandRoot(OctreeRoot* rt, uint oct, ubyte oldValue)  {
        //writefln("expandRoot(%s,%s)",oct,oldValue);
        // add branch node
        auto branch = getFreeBranch();
        rt.setOffset(oct, view.toIndex(branch));
        branch.setToSolid(oldValue);
    }
    void expandBranch(OctreeBranch* br, uint oct, ubyte oldValue)  {
        //writefln("expandBranch(%s,%s,%s)",branchToIndex(br), oct,oldValue);

        bool isParentOfLeaf() { return and==2; }

        if(isParentOfLeaf()) {
            // add leaf node
            auto leaf = getFreeLeaf();
            br.setOffset(oct, view.toIndex(leaf));

            leaf.setAllVoxels(oldValue);
        } else {
            // add branch node
            auto newBranch = getFreeBranch();
            br.setOffset(oct, view.toIndex(newBranch));

            newBranch.setToSolid(oldValue);
        }
    }
    void collapse(OctreeBranch* br, uint oct)  {
        //writefln("collapse(%s,%s) nodes.length=%s", toUint(br),oct, nodes.length);

        bool isRoot = cast(OctreeRoot*)br is &view.root;

        if(isRoot) {
            //writefln("  this is a root");
            auto root = cast(OctreeRoot*)br;
            root.setVoxel(oct, v);
        } else {
            // branch
            br.setVoxel(oct, v);

            if(br.isSolid) {
                view.freeBranches.push(view.toIndex(br));
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

    auto root  = &view.root;
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
    auto branch = view.toBranchPtr(index.offset);
    and >>= OCTREE_ROOT_BITS;
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
        branch = view.toBranchPtr(index.offset);
        and >>= 1;
    }
    // octree leaf
    oct = getOctet_1(x,y,z, 1);
    //writefln("leaf oct = %s", oct);
    //writefln("leaf index = %s", index.offset);
    auto leaf = view.toLeafPtr(index.offset);//cast(OctreeLeaf*)branch;
    ubyte v2  = leaf.getVoxel(oct);
    // no change
    if(v2==v) return;
    // change the voxel
    leaf.setVoxel(oct, v);
    if(leaf.isSolid) {
        //writefln("leaf is solid");

        // this leaf is now solid so optimise it away
        //logNodes(ptr, nodes);
        view.freeLeaves.push(view.toIndex(leaf));
        collapse(nodes.pop(), octs.pop());
    }
    //dumpNodes(nodes);
    //dump(root);
    //dump(&view.branches[0]);
//    writefln("%s branches", view.branches.length);
//    writefln("%s leaves", view.leaves.length);
//    writefln("freeBranches = %s", view.freeBranches);
//    writefln("freeLeaves = %s", view.freeLeaves);
//    foreach(i, b; view.branches) {
//        writefln("branch %s", i);
//        dump(&b);
//    }
}
