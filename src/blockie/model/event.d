module blockie.model.event;

import blockie.all;

enum EventID : ulong {
    CHUNK_ACTIVATED   = 1<<0,
    CHUNK_LOADED      = 1<<1,
    CHUNK_DEACTIVATED = 1<<2,
    CHUNK_EDITED      = 1<<3
}
