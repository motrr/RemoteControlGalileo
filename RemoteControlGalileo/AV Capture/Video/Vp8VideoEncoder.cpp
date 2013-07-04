#import "Vp8VideoEncoder.h"

#include <assert.h>
#include <stdio.h> // printf
#include <string.h> // memcpy
#include <math.h> // floor

Vp8VideoEncoder::Vp8VideoEncoder()
{
}

Vp8VideoEncoder::~Vp8VideoEncoder()
{
    printf("Processed %d frames\n", mFrameCount);
    if(vpx_codec_destroy(&mCodec))
    {
        printCodecError(&mCodec, "Failed to destroy codec");
        assert(false);
    }
    
    vpx_img_free(&mImage);
}

bool Vp8VideoEncoder::setup(int width, int height, int bitratePerPixel, int keyframeInterval)
{
    if(width < 16 || width % 2 || height < 16 || height % 2)
    {
        printf("Invalid resolution: %dx%d\n", width, height);
        return false;
    }
    
    vpx_codec_iface_t *vpxInterface = vpx_codec_vp8_cx();
    printf("Using %s\n", vpx_codec_iface_name(vpxInterface));
    
    mWidth = width;
    mHeight = height;
    mFrameCount = 0;
    mFlags = 0;
    
    // Populate encoder configuration
    vpx_codec_err_t result = vpx_codec_enc_config_default(vpxInterface, &mConfig, 0);
    if(result)
    {
        printf("Failed to get config: %s\n", vpx_codec_err_to_string(result));
        return false;
    }
    
    // Update the default configuration with our settings
    mConfig.rc_target_bitrate = (width * height * bitratePerPixel) / 1000;
    mConfig.g_w = width;
    mConfig.g_h = height;
    mConfig.kf_max_dist = keyframeInterval;
    
    printf("Target bitrate: %u\n", mConfig.rc_target_bitrate);
    
    // Initialize codec
    if(vpx_codec_enc_init(&mCodec, vpxInterface, &mConfig, 0))
    {
        printCodecError(&mCodec, "Failed to initialize encoder");
        return false;
    }
    
    if(!vpx_img_alloc(&mImage, VPX_IMG_FMT_YV12, width, height, 1))
    {
        printf("Failed to allocate image\n");
        return false;
    }
    
    return true;
}

BufferPtr Vp8VideoEncoder::encodeYUV(const void *buffer, size_t size, bool interleaved)
{
    size_t numLumaPixels = mImage.w * mImage.h;
    size_t numChromaPixels = numLumaPixels / 4;
    size_t chromaWidth = mImage.w / 2;
    size_t chromaHeight = mImage.h / 2;
    
    unsigned char *inputBuffer = (unsigned char*)buffer;

    // Alias to planes in destination image
    unsigned char *yPlane = mImage.planes[0];
    unsigned char *uPlane = yPlane + numLumaPixels;
    unsigned char *vPlane = uPlane + numChromaPixels;

    if(interleaved)
    {
        // Fill in the luma plane
        for(size_t i = 0; i < numLumaPixels; i++)
            yPlane[i] = inputBuffer[4 * i + 0];
        
        // Fill in the chroma planes (skip every second pixel)
        size_t index = 0;
        size_t offset = 0;
        for(size_t j = 0; j < chromaHeight; j++)
        {
            for(size_t i = 0; i < chromaWidth; i++, index++)
            {
                uPlane[index] = inputBuffer[offset + 8 * i + 1];
                vPlane[index] = inputBuffer[offset + 8 * i + 2];
            }
            
            offset += mImage.w * 8;
        }
    }
    else
    {
        // todo: specify some offsets inside buffer as input parameter?
        int offsetU = floor(mImage.h * 0.3 + 0.5) * mImage.w * 4;
        int offsetV = floor(mImage.h * 0.4 + 0.5) * mImage.w * 4;
        memcpy(yPlane, inputBuffer, numLumaPixels);
        memcpy(uPlane, inputBuffer + offsetU, numChromaPixels);
        memcpy(vPlane, inputBuffer + offsetV, numChromaPixels);
    }
    
    // Run through encoder
    const vpx_codec_cx_pkt_t *packet = encodeImage(&mImage);
    return packet ? BufferPtr(new WrapBuffer(packet->data.frame.buf, packet->data.frame.sz)) : BufferPtr();
}

const vpx_codec_cx_pkt_t *Vp8VideoEncoder::encodeImage(vpx_image_t *image)
{
    vpx_codec_iter_t iter = NULL;
    const vpx_codec_cx_pkt_t *packet;
    
    if(vpx_codec_encode(&mCodec, image, mFrameCount, 1, mFlags, VPX_DL_REALTIME))
    {
        printCodecError(&mCodec, "Failed to encode frame");
        return 0;
    }
    
    // Sometimes there might be more than one packet, so if you get errors this is why
    packet = vpx_codec_get_cx_data(&mCodec, &iter);
    
    if(packet->kind != VPX_CODEC_CX_FRAME_PKT)
    {
        printf("WARNING - Got a different kind of packet, don't know how to handle\n");
        // todo: skip?
    }
    /*else
    {
        // Print out stream to indicate keyframe placement
        bool keyframe = (packet->data.frame.flags & VPX_FRAME_IS_KEY);
        printf(keyframe ? "K" : ".");
    }//*/
    
    mFrameCount++;
    return packet;
}

void Vp8VideoEncoder::printCodecError(vpx_codec_ctx_t *context, const char *message)
{
    const char *detail = vpx_codec_error_detail(&mCodec);
    printf("%s: %s\n", message, vpx_codec_error(&mCodec));
    if(detail) printf("    %s\n", detail);
}
