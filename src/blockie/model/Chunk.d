module blockie.model.Chunk;

import blockie.all;

abstract class Chunk {
private:
    Mutex mutex;
public:
    const chunkcoords pos;
    const string filename;

    uint version_;  // todo - make this readonly
    ubyte[] voxels; // todo - make this readonly

    // End of data

    uint getVersion() const      { return version_; }
    ubyte[] getVoxels()          { return voxels; }
    uint getVoxelsLength() const { return cast(uint)voxels.length; }

    this(chunkcoords coords) {
        this.version_ = 0;
        this.pos      = coords;
        this.filename = "%s.%s.%s.dat".format(pos.x,pos.y,pos.z);
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
    /// Atomically copy voxels and version
    void atomicCopyTo(ref uint ver, ubyte[] dest) {
        mutex.lock();
        scope(exit) mutex.unlock();

        assert(dest.length >= voxels.length);
        ver = version_;
        dest[0..voxels.length] = voxels[];
    }

    abstract bool isAir();
    abstract bool isAirCell(uint cellIndex);
    abstract void setDistance(ubyte x, ubyte y, ubyte z);
    abstract void setCellDistance(uint cell, ubyte x, ubyte y, ubyte z);

    override string toString() {
        return "Chunk %s".format(pos.toString);
    }
}
