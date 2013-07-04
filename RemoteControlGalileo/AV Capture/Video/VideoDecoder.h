#ifndef VideoDecoder_H
#define VideoDecoder_H

#include "Buffer.h"

// todo: add option to pass custom params via string map
class VideoDecoder
{
public:
    virtual ~VideoDecoder() {}
    
    // return false in case of error
    // todo: consider moving to constructor with exceptions
    virtual bool setup() = 0;
    virtual YuvBufferPtr decodeYUV(const void *buffer, size_t size) = 0; // YV12
};

#endif