module blockie.domain.event;

import blockie.all;

enum EventID : ulong {
    CHUNK_ACTIVATED   = 1<<0,
    CHUNK_UPDATED     = 1<<1,
    CHUNK_DEACTIVATED = 1<<2
}

//final class ChunkActivated : EventMsg {
//    Chunk chunk;
//    this(Chunk chunk) {
//        this.chunk = chunk;
//    }
//    ulong getID() {
//        return EventID.CHUNK_ACTIVATED;
//    }
//    override string toString() {
//        return "ChunkActivated %s".format(chunk);
//    }
//}
//
//final class ChunkUpdated : EventMsg {
//    Chunk chunk;
//    this(Chunk chunk) {
//        this.chunk = chunk;
//    }
//    ulong getID() {
//        return EventID.CHUNK_UPDATED;
//    }
//    override string toString() {
//        return "ChunkUpdated %s".format(chunk);
//    }
//}


