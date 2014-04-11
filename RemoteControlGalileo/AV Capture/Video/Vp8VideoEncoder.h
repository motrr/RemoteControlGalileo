#ifndef Vp8VideoEncoder_H
#define Vp8VideoEncoder_H

#include "VideoEncoder.h"

#if __cplusplus
extern "C" { 
#endif

#define VPX_CODEC_DISABLE_COMPAT 1
#include "vpx_encoder.h"
#include "vp8cx.h"

#if __cplusplus
}
#endif

class Vp8VideoEncoder : public VideoEncoder
{
public:
    Vp8VideoEncoder();
    ~Vp8VideoEncoder();

    virtual bool setup(int width, int height, int bitratePerPixel, int keyframeInterval);
    virtual BufferPtr encodeYUV(const void *buffer, size_t size, bool interleaved, bool &isKey);

    unsigned int getBitrate() const { return mConfig.rc_target_bitrate; }

private:
    const vpx_codec_cx_pkt_t *encodeImage(vpx_image_t *image);
    void printCodecError(vpx_codec_ctx_t *context, const char *message);

    vpx_codec_ctx_t mCodec;
    vpx_codec_enc_cfg_t mConfig;
   
    vpx_image_t mImage;
    int mWidth;
    int mHeight;

    int mFrameCount;
    int mFlags;
};

#endif