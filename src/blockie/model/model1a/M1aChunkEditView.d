module blockie.model.model1a.M1aChunkEditView;

import blockie.model;
/*
    M1aEditView

    M1aEditRoot

    11_1100_0000 - cell oct     | M1aEditCell   | 64^3
    00_0010_0000 - branch 0 oct | M1aEditBranch | 32^8
    00_0001_0000 - branch 1 oct | M1aEditBranch | 16^8
    00_0000_1000 - branch 2 oct | M1aEditBranch | 8^8
    00_0000_0100 - branch 3 oct | M1aEditBranch | 4^8
    00_0000_0010 - leaf oct     | M1aEditLeaf   | 2^8
    00_0000_0001 - voxel oct    | Voxel         | 1^8
*/

align(1):

struct M1aEditRoot { static assert(M1aEditRoot.sizeof==M1aFlags.sizeof +
                                   M1aEditCell.sizeof*M1a_CELLS_PER_CHUNK); align(1):
    M1aFlags flags;
    M1aEditCell[M1a_CELLS_PER_CHUNK] cells;

    bool isAir() { return flags.flag == M1aFlag.AIR; }

    bool isAirCell(uint cell) {
        ASSERT(cell<M1a_CELLS_PER_CHUNK);
        return cells[cell].bits==0;
    }
    // bool isSolidCell(uint cell) {
    //     ASSERT(cell<M1a_CELLS_PER_CHUNK);
    //     return cells[cell].isSolid();
    // }
    M1aEditCell* getCell(ubyte* ptr, uint oct) {
        ASSERT(oct<M1a_CELLS_PER_CHUNK);
        return cast(M1aEditCell*)(ptr+M1aFlags.sizeof+(oct*M1aEditCell.sizeof));
    }

    void recalculateFlags() {
        flags.flag = cells[].all!(it=>it.isAir()) ? M1aFlag.AIR : M1aFlag.MIXED;
    }
    string toString() {
        auto s = "%s".format(flags.flag);
        return "Root(%s)".format(s);
    }
}
struct M1aEditCell { static assert(M1aEditCell.sizeof==5); align(1):
    ubyte flag;             ///
    ubyte bits;             /// Each bit: 0 = voxel, 1 = mixed
    union {
        ubyte voxel;        /// if !isAir() && isSolid()
        Distance3 distance; /// if isAir()
        Offset3 offset;     /// if !isAir() && !isSolid()
                            /// points to (8*M1aEditBranch)
    }


    bool isAir()         { return flag==0; }
    bool isSolid()       { return bits==0; }
    bool isAllBranches() { return bits==0xff; }
    uint numBranches()   { return popcnt(bits); }


    // void setToSolid(ubyte v) {
    //     bits  = 0;
    //     voxel = v;
    // }

    void setAsBranchAt(uint oct) {
        ASSERT(oct<8);
        bits |= cast(ubyte)(1<<oct);
    }
    // void setAsSolidAt(uint oct) {
    //     ASSERT(oct<8);
    //     bits &= cast(ubyte)~(1<<oct);
    // }

    M1aEditBranch* getBranch(ubyte* ptr, uint oct) {
        ASSERT(oct<M1a_CELLS_PER_CHUNK);
        return cast(M1aEditBranch*)(ptr+(offset.get()*4)+(oct*M1aEditBranch.sizeof));
    }
    string toString() {
        auto s = isAir() ? "AIR" : isSolid() ? "SOLID %s".format(voxel) : "MIXED";
        return "Cell(%s:%08b)".format(s,bits);
    }
}
struct M1aEditBranch { static assert(M1aEditBranch.sizeof==4); align(1):
    ubyte bits;
    union {
        ubyte voxel;    /// if isSolid()
        Offset3 offset; /// points to !isAllBranches() ? (8*ubyte voxels) + (8*M1aEditBranch or 8*M1aLeaf)
                        ///            isAllBranches() ? (8*M1aEditBranch or 8*M1aEditLeaf)
    }

    bool isSolid()       { return bits==0; }
    bool isAllBranches() { return bits==0xff; }
    uint numBranches()   { return popcnt(bits); }

    void setToSolid(ubyte v) {
        bits  = 0;
        voxel = v;
    }
    void setAsBranchAt(uint oct) {
        ASSERT(oct<8);
        bits |= cast(ubyte)(1<<oct);
    }
    // void setAsSolidAt(uint oct) {
    //     ASSERT(oct<8);
    //     bits &= cast(ubyte)~(1<<oct);
    // }

    M1aEditBranch* getBranch(ubyte* ptr, uint oct) {
        ASSERT(oct<8);
        return cast(M1aEditBranch*)(ptr+(offset.get()*4)+(oct*M1aEditBranch.sizeof));
    }
    M1aLeaf* getLeaf(ubyte* ptr, uint oct) {
        ASSERT(oct<8);
        return cast(M1aLeaf*)(ptr+(offset.get()*4)+(oct*M1aLeaf.sizeof));
    }
    string toString() {
        string s = isSolid() ? "SOLID %s".format(voxel) : "MIXED";
        return "Branch(%s:%08b)".format(s,bits);
    }
}

//================================================================================================

final class M1aChunkEditView : ChunkEditView {
private:
    enum BUFFER_INCREMENT = 1024*512;
    M1aOptimiser optimiser;
    Allocator_t!uint allocator;

    M1aChunk chunk;
    uint version_;
    ubyte[] voxels;
    uint numEdits;
    StopWatch watch;
public:
    M1aEditRoot* root() { return cast(M1aEditRoot*)voxels.ptr; }
    ulong getNumEdits() { return numEdits; }

    this() {
        this.optimiser = new M1aOptimiser(this);
        this.allocator = new Allocator_t!uint(0);
    }
    override Chunk getChunk() {
        return chunk;
    }
    override chunkcoords pos() {
        return chunk.pos;
    }
    override void beginTransaction(Chunk chunk) {
        ASSERT(chunk !is null);
        this.chunk = cast(M1aChunk)chunk;

        convertToEditable();
    }
    override void voxelEditsCompleted() {
        root.recalculateFlags();
    }
    override void commitTransaction() {

        auto optVoxels = optimiser.optimise(voxels, allocator.offsetOfLastAllocatedByte+1);

        /// Write voxels back to chunk
        uint ver = chunk.atomicUpdate(version_, optVoxels);
        if(ver!=version_+1) {
            /// Stale
            log("M1aChunkEditView: %s is stale", chunk);
        } else {
            log("Chunk %s updated to version %s", chunk, ver);
        }
    }
    override void setVoxel(uint3 offset, ubyte value) {
        watch.start();
        setVoxelInner(offset, value);
        watch.stop();
        numEdits++;
    }
    override bool isAir() {
        return root.flags.flag==M1aFlag.AIR;
    }
    override bool isAirCell(uint cell) {
        ASSERT(cell<M1a_CELLS_PER_CHUNK, "cell=%s".format(cell));
        return root.isAirCell(cell);
    }
    override void setChunkDistance(DFieldsBi f) {
        root.flags.distance.set(f);
    }
    override void setCellDistance(uint cell, uint x, uint y, uint z) {
        ASSERT(cell<M1a_CELLS_PER_CHUNK);
        ASSERT(!isAir());
        ASSERT(isAirCell(cell));

        auto c = root().getCell(voxels.ptr, cell);

        c.distance.set(x,y,z);
    }
    override void setCellDistance(uint cell, DFieldsBi f) {
        // Max = 15
        uint convert(int v) { return min(v, 15); }

        setCellDistance(cell,
            (convert(f.x.up)<<4) | convert(f.x.down),
            (convert(f.y.up)<<4) | convert(f.y.down),
            (convert(f.z.up)<<4) | convert(f.z.down)
        );
    }
private:
    void convertToEditable() {
        // todo - make this work for chunks that are not solid air
        ASSERT(chunk.isAir);

        this.version_ = chunk.getVersion();

        this.voxels.length = M1aFlags.sizeof;

        // Resize allocator to 8 bytes and allocate them
        this.allocator.resize(M1aFlags.sizeof);
        alloc(M1aFlags.sizeof);

        root().flags.flag = M1aFlag.AIR;
        root().flags.distance.clear();
    }
    void chat(A...)(lazy string fmt, lazy A args) {
        //if(chunk.pos==int3(0,0,0) && numEdits==0) {
            // writefln(format(fmt, args));
            // flushConsole();
        //}
    }
    uint alloc(uint numBytes) {
        //chat("  alloc(%s)", numBytes);
        int offset = allocator.alloc(numBytes, 4);
        if(offset==-1) {
            auto oldSize = voxels.length;
            uint newSize = allocator.length + BUFFER_INCREMENT;
            allocator.resize(newSize);
            voxels.length = newSize;
            ASSERT(allocator.length==newSize);
            ASSERT(voxels.length==newSize);

            //chat("  resize to %s (from %s)", newSize, oldSize);

            offset = allocator.alloc(numBytes, 4);

            ASSERT(offset!=-1);
        }
        ASSERT(offset < voxels.length);
        ASSERT((offset%4)==0);
        //chat("  offset=%s", offset);

        /* Set to zeroes */
        voxels[offset..offset+numBytes] = 0;

        return offset;
    }
    // void dealloc(uint offset, uint numBytes) {
    //     allocator.free(offset, numBytes);
    // }
    // (4 bits : 0..4095)
    uint getOctet_11_1100_0000(uint3 pos) {
        uint3 p = pos & 0b_0011_1100_0000;
        /// x =            0000_0000_1111 \
        /// y =            0000_1111_0000  > = zzzz_yyyy_xxxx
        /// z =            1111_0000_0000 /
        auto oct = (p.x>>>6) | (p.y>>>2) | (p.z<<2);
        ASSERT(oct<4096);
        return oct;
    }
    // (5 bits : 0..32767)
    // uint getOctet_11_1110_0000(uint3 pos) {
    //     uint3 p = pos & 0b_000_0011_1110_0000;
    //     /// x =            000_0000_0001_1111 \
    //     /// y =            000_0011_1110_0000  > = zzz_zzyy_yyyx_xxxx
    //     /// z =            111_1100_0000_0000 /
    //     auto oct = (p.x>>>5) | (p.y) | (p.z<<5);
    //     ASSERT(oct<32768);
    //     return oct;
    // }
    /// (1 bit : 0..7)
    /// bitpos: 0..31
    uint getOctet(uint3 pos, uint bitpos) {
        uint3 p = (pos >>> bitpos) & 1;
        /// x =            0000_0000_0001 \
        /// y =            0000_0000_0010  > = 0000_0000_0zyx
        /// z =            0000_0000_0100 /
        auto oct = p.x | (p.y<<1) | (p.z<<2);
        ASSERT(oct<8);
        return oct;
    }
    uint toUint(void* c) {
        return cast(uint)(cast(ulong)c-cast(ulong)voxels.ptr);
    }
    M1aEditCell* toCell(uint o) {
        return cast(M1aEditCell*)(voxels.ptr+o);
    }
    M1aEditBranch* toBranch(uint o) {
        return cast(M1aEditBranch*)(voxels.ptr+o);
    }
    M1aLeaf* toLeaf(uint o) {
        return cast(M1aLeaf*)(voxels.ptr+o);
    }
    M1aEditCell* expandCell(M1aEditCell* cell, uint oct4, ubyte oldValue) {
        ASSERT(cell.numBranches()<8);

        /// If this is the first branch then alloc space
        if(cell.numBranches()==0) {
            auto temp   = toUint(cell);
            uint offset = alloc(8*M1aEditBranch.sizeof);

            /// Refresh our cell ptr as it may have changed if voxels were resized
            cell = toCell(temp);

            cell.offset.set(offset/4);
        }
        cell.setAsBranchAt(oct4);

        auto branch = cell.getBranch(voxels.ptr, oct4);
        branch.setToSolid(oldValue);

        return cell;
    }
    M1aEditBranch* expandBranch(M1aEditBranch* branch, uint oct, ubyte oldValue, bool isAboveLeaf) {
        ASSERT(branch.numBranches()<8);

        auto elementSize = isAboveLeaf ? M1aLeaf.sizeof : M1aEditBranch.sizeof;

        /// If this is the first branch then alloc space
        if(branch.numBranches()==0) {
            auto temp   = toUint(branch);
            uint offset = alloc(8*elementSize.as!uint);

            /// Refresh our branch ptr as it may have changed if voxels were resized
            branch = toBranch(temp);

            branch.offset.set(offset/4);
        }
        branch.setAsBranchAt(oct);

        if(isAboveLeaf) {
            auto leaf = branch.getLeaf(voxels.ptr, oct);
            leaf.setAllVoxels(oldValue);
        } else {
            auto subbranch = branch.getBranch(voxels.ptr, oct);
            subbranch.setToSolid(oldValue);
        }

        return branch;
    }
    void setVoxelInner(uint3 offset, ubyte voxel) {

        chat("===========================");
        chat("setVoxel %s to %s", offset, voxel);
        chat("===========================");

        // thread locals
        // static Stack!(M1aEditBranch*) nodes;
        // static Stack!uint octs;
        // if(!nodes) {
        //     nodes  = new Stack!(M1aEditBranch*)(CHUNK_SIZE_SHR);
        //     octs   = new Stack!uint(CHUNK_SIZE_SHR);
        // } else {
        //     nodes.clear();
        //     octs.clear();
        // }



        if(root().isAir()) {
            // Allocate cells
            chat("Allocating cells");
            ASSERT(voxels.length==8);
            ASSERT(allocator.numBytesUsed==8);
            ASSERT(8==alloc(M1aEditCell.sizeof*M1a_CELLS_PER_CHUNK));

            // Root is now MIXED
            root().flags.flag = M1aFlag.MIXED;

            ASSERT(allocator.numBytesUsed==M1aEditRoot.sizeof);
        }

        chat("root = %s", root().toString());

        // 11_1100_0000 - Cell
        // 00_0010_0000 - Branch0
        // 00_0001_0000 - Branch1
        // 00_0000_1000 - Branch2
        // 00_0000_0100 - Branch3
        // 00_0000_0010 - Leaf
        // 00_0000_0001 - Voxel

        // M1aEditBranch*[4] branches;
        // uint[4] octs;

        // Cell -> Branch0
        uint cellOct    = getOctet_11_1100_0000(offset);
        auto cell       = root().getCell(voxels.ptr, cellOct);
        uint branch0oct = getOctet(offset, 5);

        chat("cell       = %s (cellOct=%s)", cell.toString(), cellOct);
        chat("branch0oct = %s", branch0oct);

        if(cell.isSolid()) {
            ubyte v = cell.voxel;
            if(v==voxel) return; // if it's the same then we are done

            cell = expandCell(cell, branch0oct, v);
        }

        // Branch0 -> branch1
        auto branch0    = cell.getBranch(voxels.ptr, branch0oct);
        uint branch1oct = getOctet(offset, 4);
        chat("branch1oct = %s", branch1oct);

        if(branch0.isSolid()) {
            ubyte v = branch0.voxel;
            if(v==voxel) return; // if it's the same then we are done

            branch0 = expandBranch(branch0, branch1oct, v, false);
        }

        // Branch1 -> Branch2
        auto branch1    = branch0.getBranch(voxels.ptr, branch1oct);
        uint branch2oct = getOctet(offset, 3);
        chat("branch2oct = %s", branch2oct);

        if(branch1.isSolid()) {
            ubyte v = branch1.voxel;
            if(v==voxel) return; // if it's the same then we are done

            branch1 = expandBranch(branch1, branch2oct, v, false);
        }

        // Branch2 -> Branch3
        auto branch2    = branch1.getBranch(voxels.ptr, branch2oct);
        uint branch3oct = getOctet(offset, 2);
        chat("branch3oct = %s", branch3oct);

        if(branch2.isSolid()) {
            ubyte v = branch2.voxel;
            if(v==voxel) return; // if it's the same then we are done

            branch2 = expandBranch(branch2, branch3oct, v, false);
        }

        // Branch3 -> Leaf
        auto branch3 = branch2.getBranch(voxels.ptr, branch3oct);
        uint leafOct = getOctet(offset, 1);
        chat("leafOct = %s", leafOct);

        if(branch3.isSolid()) {
            ubyte v = branch3.voxel;
            if(v==voxel) return; // if it's the same then we are done

            branch3 = expandBranch(branch3, leafOct, v, true);
        }

        auto leaf     = branch3.getLeaf(voxels.ptr, leafOct);
        uint voxelOct = getOctet(offset, 0);
        chat("voxelOct = %s", voxelOct);

        ubyte v = leaf.getVoxel(voxelOct);
        if(v==voxel) return;

        leaf.setVoxel(voxelOct, voxel);

        chat("%s", leaf.toString());
    }
}