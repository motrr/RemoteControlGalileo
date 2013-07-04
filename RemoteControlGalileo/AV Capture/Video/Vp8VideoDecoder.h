#ifndef Vp8VideoDecoder_H
#define Vp8VideoDecoder_H

#include "VideoDecoder.h"

#if __cplusplus
extern "C" { 
#endif

#define VPX_CODEC_DISABLE_COMPAT 1
#include "vpx_decoder.h"
#include "vp8dx.h"

#if __cplusplus
}
#endif

class Vp8VideoDecoder : public VideoDecoder
{
public:
    Vp8VideoDecoder();
    ~Vp8VideoDecoder();

    virtual bool setup();
    virtual YuvBufferPtr decodeYUV(const void *buffer, size_t size);

private:
    void printCodecError(vpx_codec_ctx_t *context, const char *message);

    vpx_codec_ctx_t mCodec;
    int mFrameCount;
    int mFlags;
};

#endif