#ifndef VideoEncoder_H
#define VideoEncoder_H

#include "Buffer.h"

// todo: add option to pass custom params via string map
class VideoEncoder
{
public:
    virtual ~VideoEncoder() {}
    
    // return false in case of error
    // todo: consider moving to constructor with exceptions
    virtual bool setup(int width, int height, int bitratePerPixel, int keyframeInterval) = 0;
    virtual BufferPtr encodeYUV(const void *buffer, size_t size, bool interleaved) = 0; // YV12
};

#endif