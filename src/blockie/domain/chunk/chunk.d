module blockie.domain.chunk.chunk;

import blockie.all;
/**
 * size 16   (4)  =         4,096 voxels
 * size 32   (5)  =        32,768 voxels
 * size 64   (6)  =       262,144 voxels
 * size 128  (7)  =     2,097,152 voxels (2MB)
 * size 256  (8)  =    16,777,216 voxels (16MB)
 * size 512  (9)  =   134,217,728 voxels (128MB)
 * size 1024 (10) = 1,073,741,824 voxels (1GB)
 */
const CHUNK_SIZE_SHR    = 10;    // 6 to 10
const OCTREE_ROOT_BITS  = 4;    // 1 to 5

const CHUNK_SIZE         = 2^^CHUNK_SIZE_SHR;
const CHUNK_SIZE_SQUARED = CHUNK_SIZE*CHUNK_SIZE;
static assert(CHUNK_SIZE_SHR>=6 && CHUNK_SIZE_SHR<=10);
static assert(OCTREE_ROOT_BITS>0 && OCTREE_ROOT_BITS<6);

final class Chunk {
    @Comment("In chunk coords")
    const ivec3 pos;
    const string filename;

    struct { // voxel state
        ubyte[] voxels;
        uint version_;
    }

    auto beginEdit() {
        return new ChunkEditView(this);
    }
    void endEdit(ChunkEditView view) {
        voxels = view.getOptimisedVoxels();
        version_++;
    }

    OctreeRoot* root() { return cast(OctreeRoot*)voxels.ptr; }
    OptimisedRoot* optimisedRoot() { return cast(OptimisedRoot*)voxels.ptr; }

    bool isAir() { return root().flags.flag==OctreeFlag.AIR; }

    // in chunk coords
    private this(ivec3 chunkPos) {
        this.pos          = chunkPos;
        this.filename     = "%s.%s.%s.dat".format(pos.x,pos.y,pos.z);
        this.voxels.assumeSafeAppend();
    }
    static Chunk airChunk(ivec3 chunkPos) {
        Chunk c = new Chunk(chunkPos);
        c.setToAir();
        return c;
    }
    static Chunk uninitialisedChunk(ivec3 chunkPos) {
        return new Chunk(chunkPos);
    }
    //====================================================
    void setToAir() {
        // only need to set the air flag
        voxels.length = OctreeFlags.sizeof;
        voxels[]      = 0;
        root().flags.flag = OctreeFlag.AIR;
    }
    override string toString() {
        return "Chunk %s".format(pos.toString);
    }
}

