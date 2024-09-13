module blockie.model.Chunk;

import blockie.model;

abstract class Chunk {
public:
    const chunkcoords pos;
    const string filename;

    abstract bool isAir();

    uint getVersion() { return version_; }

    this(chunkcoords coords) {
        this.version_ = 0;
        this.pos      = coords;
        this.filename = "%s.%s.%s.dat".format(pos.x, pos.y, pos.z);
        this.mutex    = new Mutex;
    }
    /// Atomically update chunk state if ver == current chunk version.
    /// Returns new chunk version.
    uint atomicUpdate(uint ver, ubyte[] voxels) {
        mutex.lock();
        scope(exit) mutex.unlock();

        if(version_ == ver) {
            this.version_ = version_+1;

            /// If voxels are null then this is just a bump to version 1 and this chunk is AIR
            if(voxels.length>0) {
                this.voxels = voxels.dup;
            }
        }
        return version_;
    }
    void atomicGet(out uint ver, out immutable(ubyte)[] dest) {
        mutex.lock();
        scope(exit) mutex.unlock();

        ver = version_;
        dest = voxels.as!(immutable(ubyte)[]);
    }

    override string toString() {
        return "Chunk %s".format(pos.toString());
    }
protected:
    // Note: Voxels here are always assumed to be optimised. Editing is performed on a
    // copy which is then written back here via 'atomicUpdate'.
    ubyte[] voxels; 
private:
    Mutex mutex;
    uint version_;      
}
