module blockie.domain.chunk.chunk_view;
/**
 *  An editable view of a Chunk. Start editing by calling
 *      chunk.beginEdit()
 *  and finish by calling
 *      chunk.endEdit(editView)
 *
 *  TODO - cache these so that we don't keep creating and destroying them each time.
 */
import blockie.all;

final class ChunkEditView {
    Chunk chunk;
    OctreeRoot root;
    OctreeBranch[] branches;
    OctreeBranch[] l2Branches;
    OctreeLeaf[] leaves;
    Stack!uint freeLeaves;
    Stack!uint freeBranches;

    this(Chunk chunk) {
        this.chunk        = chunk;
        this.freeLeaves   = new Stack!uint(8);
        this.freeBranches = new Stack!uint(8);
        this.branches.assumeSafeAppend();
        this.leaves.assumeSafeAppend();
        convertFromVoxels();
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
    //bool isAir() const { return root.flags.flag == OctreeFlag.AIR; }
    override string toString() {
        return "EditView for " ~ (chunk ? chunk.toString() : "[NULL chunk]");
    }
private:
    void convertFromVoxels() {
        // todo - this only works if the chunk is solid air

        expect(chunk.isAir);

        root            = OctreeRoot();
        branches.length = 0;
        leaves.length   = 0;
    }
}

