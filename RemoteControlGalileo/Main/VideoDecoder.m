//
//  VideoDecoder.m
//  RemoteControlGalileo
//
//  Created by Chris Harding on 02/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoDecoder.h"
#import "VideoTxRxCommon.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#define VPX_CODEC_DISABLE_COMPAT 1

#include "vpx_decoder.h"
#include "vp8dx.h"
#define interface (vpx_codec_vp8_dx())


#define IVF_FILE_HDR_SZ  (32)
#define IVF_FRAME_HDR_SZ (12)


static void decoder_die(const char *fmt, ...) {
    va_list ap;
    
    va_start(ap, fmt);
    vprintf(fmt, ap);
    if(fmt[strlen(fmt)-1] != '\n')
        printf("\n");
    exit(EXIT_FAILURE);
}

static void decoder_die_codec(vpx_codec_ctx_t *ctx, const char *s) {
    const char *detail = vpx_codec_error_detail(ctx);
    //
    printf("%s: %s\n", s, vpx_codec_error(ctx));
    if(detail)
        printf("    %s\n",detail);
    exit(EXIT_FAILURE);
}

static vpx_codec_ctx_t  decoder_codec;
static int              decoder_flags = 0, decoder_frame_cnt = 0;
//static vpx_codec_err_t  decoder_res;

@implementation VideoDecoder

- (id) init
{
    if (self = [super init]) {
        printf("Using %s\n",vpx_codec_iface_name(interface));
        /* Initialize codec */
        if(vpx_codec_dec_init(&decoder_codec, interface, NULL, decoder_flags))
            decoder_die_codec(&decoder_codec, "Failed to initialize decoder");
        yuvBuffer = 0;
    }
    return self;
}

- (void) dealloc
{
    printf("Processed %d frames.\n",decoder_frame_cnt);
    freeYuvBuffer(&yuvBuffer);
    
    if(vpx_codec_destroy(&decoder_codec))
        decoder_die_codec(&decoder_codec, "Failed to destroy codec");
}

- (YuvBuffer*) decodeFrameDataBuffer: (NSData*) data
{
    vpx_codec_iter_t iter = NULL;
    decoder_frame_cnt++;
    
    /* Decode the frame */
    if(vpx_codec_decode(&decoder_codec, [data bytes], [data length], NULL, 0))
        decoder_die_codec(&decoder_codec, "Failed to decode frame");
    
    /* Write decoded data to buffer */
    vpx_image_t * img = vpx_codec_get_frame(&decoder_codec, &iter);
    
    // Create buffer
    /*if(!yuvBuffer || yuvBuffer->width != img->d_w || yuvBuffer->height != img->d_h)
    {
        freeYuvBuffer(&yuvBuffer);
        yuvBuffer = createYuvBuffer(img->d_w, img->d_h);
    }

    // Create pixel buffer from image data bytes
    // Seems like manualy craeted kCVPixelFormatType_420YpCbCr8PlanarVideoRange not supported
    /*size_t planeWidths[] = { yuvBuffer->width, yuvBuffer->width / 2, yuvBuffer->width / 2 };
    size_t planeHeights[] = { yuvBuffer->height, yuvBuffer->height / 2, yuvBuffer->height / 2 };
    void *planeAdresses[] = { CFSwapInt32HostToBig((int32_t)yuvBuffer->planes[0]), 
                              CFSwapInt32HostToBig((int32_t)yuvBuffer->planes[1]), 
                              CFSwapInt32HostToBig((int32_t)yuvBuffer->planes[2]), };
    
    
    CVPlanarPixelBufferInfo_YCbCrPlanar *planarAttr = (CVPlanarPixelBufferInfo_YCbCrPlanar*)yuvBuffer->base;
    planarAttr->componentInfoY.offset = CFSwapInt32HostToBig(sizeof(CVPlanarPixelBufferInfo_YCbCrPlanar));
    planarAttr->componentInfoY.rowBytes = yuvBuffer->width;
    planarAttr->componentInfoCb.offset = CFSwapInt32HostToBig(planarAttr->componentInfoY.offset + yuvBuffer->width * yuvBuffer->height);
    planarAttr->componentInfoCb.rowBytes = yuvBuffer->width / 2;
    planarAttr->componentInfoCr.offset = CFSwapInt32HostToBig(planarAttr->componentInfoCb.offset + yuvBuffer->width * yuvBuffer->height / 4);
    planarAttr->componentInfoCr.rowBytes = yuvBuffer->width / 2;
    
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn err = CVPixelBufferCreateWithPlanarBytes(NULL,
                                       img->d_w, img->d_h,
                                       kCVPixelFormatType_420YpCbCr8PlanarVideoRange,
                                       yuvBuffer->base,
                                       (img->d_w * img->d_h * 3) / 2,
                                       2,
                                       planeAdresses,
                                       planeWidths, planeHeights,
                                       planeWidths,
                                       NULL, 0, 0,
                                       &pixelBuffer);//*/
    
    // Fill the buffer
    //for(int i = 0; i < 3; i++) {
        /*CVPixelBufferLockBaseAddress(yuvBuffer->buffers[i], 0);
        unsigned char* base_address = (unsigned char*) CVPixelBufferGetBaseAddress(yuvBuffer->buffers[i]);//*/
    
        /*unsigned char * dest = yuvBuffer->planes[i];
        unsigned char * src = img->planes[i];
        int h = img->d_h >> ((i > 0) ? 1 : 0);

        for(int j = 0; j < h; j++) {
            memcpy(dest, src, yuvBuffer->stride[i]);

            dest += yuvBuffer->stride[i];
            src += img->stride[i];
        }
        
        //CVPixelBufferUnlockBaseAddress(yuvBuffer->buffers[i], 0);
    //}
    
    /*freePixelBuffer(yuvBuffer);
    createPixelBuffer(yuvBuffer);*/
    
    freeYuvBuffer(&yuvBuffer);
    yuvBuffer = createYuvBufferVpx(img); // wrap the vpx image, no mem copy
    
    return yuvBuffer;
}

@end

YuvBuffer *createYuvBufferVpx(void *vpxImage)
{
    vpx_image_t *image = (vpx_image_t*)vpxImage;
    
    YuvBuffer *buffer = (YuvBuffer*)malloc(sizeof(YuvBuffer));
    buffer->width = image->d_w;
    buffer->height = image->d_h;
    buffer->stride[0] = image->stride[0];
    buffer->stride[1] = image->stride[1];
    buffer->stride[2] = image->stride[2];
    buffer->fromVpxImage = true;
    
    buffer->base = image->planes[0];
    buffer->planes[0] = image->planes[0];
    buffer->planes[1] = image->planes[1];
    buffer->planes[2] = image->planes[2];
    
    for(int i = 0; i < 3; i++)
        buffer->buffers[i] = 0;
    
    return buffer;
}

YuvBuffer *createYuvBuffer(int width, int height)
{
    YuvBuffer *buffer = (YuvBuffer*)malloc(sizeof(YuvBuffer));
    buffer->width = width;
    buffer->height = height;
    buffer->stride[0] = width;
    buffer->stride[1] = width / 2;
    buffer->stride[2] = buffer->stride[1];
    buffer->fromVpxImage = false;
    
    int ysize = width * height;
    int usize = ysize / 4;
    int size = (ysize * 3) / 2;
    
    buffer->base = (unsigned char*)malloc(size);
    buffer->planes[0] = buffer->base;
    buffer->planes[1] = buffer->planes[0] + ysize;
    buffer->planes[2] = buffer->planes[1] + usize;
    
    for(int i = 0; i < 3; i++)
        buffer->buffers[i] = 0;
    
    return buffer;
}

void createPixelBuffer(YuvBuffer *buffer)
{
    for(int i = 0; i < 3; i++)
    {
        buffer->buffers[i] = 0;
        
        int h = (i == 0) ? buffer->height : buffer->height / 2;
        CVPixelBufferCreateWithBytes(NULL, 
                                     buffer->stride[i], h, 
                                     kCVPixelFormatType_OneComponent8, // not supported on iOS 5.0
                                     buffer->planes[i],
                                     buffer->stride[i], 
                                     NULL, NULL, NULL,
                                     &buffer->buffers[i]);
    }
}

void freePixelBuffer(YuvBuffer *buffer)
{
    if(buffer) {
        for(int i = 0; i < 3; i++) {
            if(buffer->buffers[i]) {
                CVPixelBufferRelease(buffer->buffers[i]);
                buffer->buffers[i] = 0;
            }
        }
    }
}

void freeYuvBuffer(YuvBuffer **buffer)
{
    if(*buffer) {
        if(!(*buffer)->fromVpxImage) {
            freePixelBuffer(*buffer);
            free((*buffer)->base);
        }
        
        free(*buffer);
        *buffer = 0;
    }
}
