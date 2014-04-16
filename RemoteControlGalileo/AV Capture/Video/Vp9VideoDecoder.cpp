#import "Vp9VideoDecoder.h"

Vp9VideoDecoder::Vp9VideoDecoder():
mFrameCount(0),
mFlags(0)
{
}

Vp9VideoDecoder::~Vp9VideoDecoder()
{
    printf("Processed %d frames\n", mFrameCount);
    if(vpx_codec_destroy(&mCodec))
    {
        printCodecError(&mCodec, "Failed to destroy codec");
        assert(false);
    }
}

bool Vp9VideoDecoder::setup()
{
    vpx_codec_iface_t *vpxInterface = vpx_codec_vp9_dx();
    printf("Using %s\n", vpx_codec_iface_name(vpxInterface));
    
    // Initialize codec
    if(vpx_codec_dec_init(&mCodec, vpxInterface, NULL, mFlags))
    {
        printCodecError(&mCodec, "Failed to initialize decoder");
        return false;
    }
    
    mFrameCount = 0;
    mFlags = 0;

    return true;
}

YuvBufferPtr Vp9VideoDecoder::decodeYUV(const void *buffer, size_t size)
{
    vpx_codec_iter_t iter = NULL;
    mFrameCount++;
    
    // Decode the frame
    if(vpx_codec_decode(&mCodec, (const uint8_t*)buffer, size, NULL, 0))
    {
        printCodecError(&mCodec, "Failed to decode frame");
        return YuvBufferPtr();
    }
    
    // Write decoded data to buffer
    vpx_image_t *image = vpx_codec_get_frame(&mCodec, &iter);
    
    if(!image)
    {
        return YuvBufferPtr();
    }
    
    //
    void *planes[3] = { image->planes[0], image->planes[1], image->planes[2] };
    size_t stride[3] = { image->stride[0], image->stride[1], image->stride[2] };
    size = (image->w * image->h * 3) / 2;
    
    return YuvBufferPtr(new YuvWrapBuffer(image->d_w, image->d_h, planes, stride, size));
}

void Vp9VideoDecoder::printCodecError(vpx_codec_ctx_t *context, const char *message)
{
    const char *detail = vpx_codec_error_detail(&mCodec);
    printf("%s: %s\n", message, vpx_codec_error(&mCodec));
    if(detail) printf("    %s\n", detail);
}
