//
//  VideoDecoder.m
//  GalileoHD
//
//  Created by Chris Harding on 02/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoDecoder.h"

#import "GalileoCommon.h"

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

static unsigned int mem_get_le32(const unsigned char *mem) {
    return (mem[3] << 24)|(mem[2] << 16)|(mem[1] << 8)|(mem[0]);
}

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

unsigned char * output[1024*1024];

static vpx_codec_err_t  decoder_res;

@implementation VideoDecoder

- (id) init
{
    if (self = [super init]) {
        
        //luma = (unsigned char*) calloc(VIDEO_WIDTH*VIDEO_HEIGHT*4, 1);
        
        (void)decoder_res;
        
        printf("Using %s\n",vpx_codec_iface_name(interface));
        /* Initialize codec */
        if(vpx_codec_dec_init(&decoder_codec, interface, NULL, decoder_flags))
            decoder_die_codec(&decoder_codec, "Failed to initialize decoder");
        
    }
    return self;
}



- (void) dealloc
{
    printf("Processed %d frames.\n",decoder_frame_cnt);
    if(vpx_codec_destroy(&decoder_codec))
        decoder_die_codec(&decoder_codec, "Failed to destroy codec");
}

- (CVPixelBufferRef) decodeFrameData: (NSData*) data
{
    vpx_codec_iter_t  iter = NULL;
    decoder_frame_cnt++;
    
    /* Decode the frame */
    if(vpx_codec_decode(&decoder_codec, [data bytes], [data length], NULL, 0))
        decoder_die_codec(&decoder_codec, "Failed to decode frame");
    
    /* Write decoded data to buffer */
    vpx_image_t * img = vpx_codec_get_frame(&decoder_codec, &iter);
    
    // Grab the luma component
    luma = img->planes[0];
    unsigned int stride = img->stride[0];
    
    unsigned int width = VIDEO_WIDTH;
    unsigned int height = VIDEO_HEIGHT;
    
    // Convert to RGB pixelbuffer (still greyscale
    char* bgra_frame = malloc(width*height*4);
    for (unsigned int i=0; i<height; i++) {
        for (unsigned int j=0; j<width; j++) {
            
            unsigned int src_idx = (i*stride) + j;
            unsigned int dst_idx = (i*width) + j;
            
            bgra_frame[4*dst_idx+0] = luma[src_idx];
            bgra_frame[4*dst_idx+1] = luma[src_idx];
            bgra_frame[4*dst_idx+2] = luma[src_idx];
            bgra_frame[4*dst_idx+3] = 0xFF;
            
        }
    }
    
    // Create pixel buffer from image data bytes
    CVPixelBufferRef pixelBuffer = NULL;

    CVPixelBufferCreateWithBytes(NULL,
                                 width, height,
                                 kCVPixelFormatType_32BGRA,
                                 bgra_frame,
                                 width*4,
                                 pixelBufferReleaseCallback, 0, NULL,
                                 &pixelBuffer);
    
    return pixelBuffer;
}

void pixelBufferReleaseCallback(void *releaseRefCon, const void *baseAddress)
{
    // Alias to the entire buffer, including the JPEG framgment header
    char* old_frame = (char*)baseAddress;
    
    // Deallocate
    free(old_frame);
}


@end
