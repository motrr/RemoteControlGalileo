#ifndef AudioDecoder_H
#define AudioDecoder_H

#include "Buffer.h"

// todo: add option to pass custom params via string map
class AudioDecoder
{
public:
    virtual ~AudioDecoder() {}
    
    // return false in case of error
    // todo: consider moving to constructor with exceptions
    virtual bool setup() = 0;
    // size = input buffer size, output actualy proccessed size
    // if input size > maximum input size and discardFrames is on, everything above will be discarded
    virtual BufferPtr decode(const void *buffer, size_t size) = 0;
};

#endif