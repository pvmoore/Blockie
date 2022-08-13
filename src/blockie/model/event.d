module blockie.model.event;

import blockie.model;

enum EventID : ulong {
    NONE              = 0,

    CHUNK_ACTIVATED   = 1<<0,   // Chunk
    CHUNK_LOADED      = 1<<1,   // Chunk
    CHUNK_DEACTIVATED = 1<<2,   // Chunk
    CHUNK_EDITED      = 1<<3,   // Chunk

    STORAGE_READ      = 1<<10,  // double - total bytes read
    STORAGE_WRITE     = 1<<11,  // double - total bytes written

    GPU_WRITES                 = 1<<12,
    GPU_VOXELS_USAGE           = 1<<13,
    GPU_CHUNKS_USAGE           = 1<<14,
    CM_CAMERA_MOVE_UPDATE_TIME = 1<<15,
    CM_CHUNK_UPDATE_TIME       = 1<<16,

    CHUNKS_TOTAL        = 1<<17,
    CHUNKS_ON_GPU       = 1<<18,
    CHUNKS_READY        = 1<<19,
    CHUNKS_FLYWEIGHT    = 1<<20,

    COMPUTE_TIME        = 1<<21,

    MEM_USED                    = 1<<22,
    MEM_RESERVED                = 1<<23,
    MEM_TOTAL_COLLECTIONS       = 1<<24,
    MEM_TOTAL_COLLECTION_TIME   = 1<<25,
}
