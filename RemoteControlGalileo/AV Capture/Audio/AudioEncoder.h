#ifndef AudioEncoder_H
#define AudioEncoder_H

#include "Buffer.h"

// todo: add option to pass custom params via string map
class AudioEncoder
{
public:
    virtual ~AudioEncoder() {}
    
    // return false in case of error
    // todo: consider moving to constructor with exceptions
    virtual bool setup(int sampleRate, int channels, int bitsPerChannel) = 0;
    // size = input buffer size, output actualy proccessed size
    // if input size > maximum input size and discardFrames is on, everything above will be discarded
    virtual BufferPtr encode(const void *buffer, size_t &size, bool discardFrames) = 0;
};

#endif