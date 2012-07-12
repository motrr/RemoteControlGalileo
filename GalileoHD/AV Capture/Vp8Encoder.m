//
//  VideoEncoder.m
//  GalileoHD
//
//  Created by Chris Harding on 01/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "Vp8Encoder.h"
#import "VideoTxRxCommon.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#define OUTPUT_WIDTH    GLOBAL_WIDTH
#define OUTPUT_HEIGHT   GLOBAL_HEIGHT

// Don't know why this is needed, probably some frame header
#define UNKNOWN_IMG_OFFSET 64

#define VPX_CODEC_DISABLE_COMPAT 1

#include "vpx_encoder.h"
#include "vp8cx.h"

#define vpx_interface (vpx_codec_vp8_cx())
#define fourcc    0x30385056

#define IVF_FILE_HDR_SZ  (32)
#define IVF_FRAME_HDR_SZ (12)

static void mem_put_le16(char *mem, unsigned int val) {
    mem[0] = val;
    mem[1] = val>>8;
}

static void mem_put_le32(char *mem, unsigned int val) {
    mem[0] = val;
    mem[1] = val>>8;
    mem[2] = val>>16;
    mem[3] = val>>24;
}

static void die(const char *fmt, ...) {
    va_list ap;
    
    va_start(ap, fmt);
    vprintf(fmt, ap);
    if(fmt[strlen(fmt)-1] != '\n')
        printf("\n");
    exit(EXIT_FAILURE);
}

static void die_codec(vpx_codec_ctx_t *ctx, const char *s) {
    const char *detail = vpx_codec_error_detail(ctx);
    
    printf("%s: %s\n", s, vpx_codec_error(ctx));
    if(detail) printf("    %s\n",detail);
    exit(EXIT_FAILURE);
}

static int read_frame(FILE *f, vpx_image_t *img) {
    
    size_t nbytes, to_read;
    int    res = 1;
    
    to_read = (img->w * img->h * 3) / 2;
    nbytes = fread(img->planes[0], 1, to_read, f);
    img->fmt = VPX_IMG_FMT_YV12;
    
    if(nbytes != to_read) {
        res = 0;
        if(nbytes > 0)
            printf("Warning: Read partial frame. Check your width & height!\n");
    }
    
    return res;
}

@interface Vp8Encoder ()
{
    vpx_codec_ctx_t      codec;
    vpx_codec_enc_cfg_t  cfg;
    int                  frame_cnt;
    vpx_codec_err_t      res;
    int                  frame_avail;
    int                  got_data;
    int                  flags;
    
    vpx_image_t raw;
}

@end

@implementation Vp8Encoder

- (id) init
{
    if (self = [super init]) {
        
        frame_cnt = 0;
        flags = 0;
        
        [self setup_encoder];
        
    }
    return self;
}

- (int) setup_encoder
{
    long width = VIDEO_WIDTH;
    long height = VIDEO_HEIGHT;
    
    // Create image using dimensions
    if(width < 16 || width%2 || height <16 || height%2)
        die("Invalid resolution: %ldx%ld", width, height);
    
    printf("Using %s\n",vpx_codec_iface_name(vpx_interface));
    
    /* Populate encoder configuration */
    res = vpx_codec_enc_config_default(vpx_interface, &cfg, 0);
    if(res) {
        printf("Failed to get config: %s\n", vpx_codec_err_to_string(res));
        return EXIT_FAILURE;
    }
    
    /* Update the default configuration with our settings */
    cfg.rc_target_bitrate = width * height * cfg.rc_target_bitrate
    / cfg.g_w / cfg.g_h;
    cfg.g_w = width;
    cfg.g_h = height;
    cfg.kf_max_dist = 0;
    
    /* Initialize codec */
    if(vpx_codec_enc_init(&codec, vpx_interface, &cfg, 0))
        die_codec(&codec, "Failed to initialize encoder");
    
    frame_avail = 1;
    got_data = 0;
    
    if(!vpx_img_alloc(&raw, VPX_IMG_FMT_YV12, width, height, 1))
        die("Failed to allocate image", width, height);
    
    return EXIT_SUCCESS;
}

- (void) dealloc
{
    printf("Processed %d frames.\n",frame_cnt-1);
    if(vpx_codec_destroy(&codec))
        die_codec(&codec, "Failed to destroy codec");
}

- (NSData*) frameDataFromPixelBuffer: (CVPixelBufferRef) pixelBuffer
{
    vpx_image_t * img = &raw;
    size_t num_pixels = img->w * img->h;
    size_t num_luma_pixels = img->w * img->h;
    size_t num_chroma_pixels = (img->w * img->h) / 4;
    
    // Get access to raw pixel data
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    unsigned char* base_address = (unsigned char*) CVPixelBufferGetBaseAddress(pixelBuffer);
    
    // Alias to planes in source image
    unsigned char* bgra_planes = base_address;
    
    // Alias to planes in destination image
    unsigned char* y_plane_dst = img->planes[0];
    unsigned char* u_plane = y_plane_dst + num_luma_pixels;
    unsigned char* v_plane = u_plane + num_chroma_pixels;
    
    // Generate the luma plane
    for (unsigned int i=0; i < num_pixels; i++) {
        y_plane_dst[i] = (0.257 * bgra_planes[4*i+2]) + (0.504 * bgra_planes[4*i+1]) + (0.098 * bgra_planes[4*i]) + 16;
    }
    
    // Blank out the YV planes
    for (unsigned int i = 0; i < num_chroma_pixels; i++) {
        v_plane[i] = 0x00;
        u_plane[i] = 0x00;
    }
    
    // Run through encoder
    const vpx_codec_cx_pkt_t * pkt = [self encode_frame:img];
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    // Ensure frame isn't too big
    assert(pkt->data.frame.sz <= MAX_FRAME_LENGTH);
    
    // Wrap frame in ObjC object and return
    NSData* frameData = [NSData dataWithBytesNoCopy:pkt->data.frame.buf length:pkt->data.frame.sz freeWhenDone:NO ];
    return frameData;
}

- (const vpx_codec_cx_pkt_t *) encode_frame: (vpx_image_t *) raw_img
{
    vpx_codec_iter_t iter = NULL;
    const vpx_codec_cx_pkt_t *pkt;
    
    if(vpx_codec_encode(&codec, raw_img, frame_cnt, 1, flags, VPX_DL_REALTIME))
        die_codec(&codec, "Failed to encode frame");
    
    // Sometimes there might be more than one packet, so if you get errors this is why
    pkt = vpx_codec_get_cx_data(&codec, &iter);
    
    if (pkt->kind != VPX_CODEC_CX_FRAME_PKT) {
       printf("WARNING - Got a different kind of packet, don't know how to handle");
    }
    
    // Print out stream to indicate keyframe placement
    printf(pkt->kind == VPX_CODEC_CX_FRAME_PKT
           && (pkt->data.frame.flags & VPX_FRAME_IS_KEY)? "K":".");
    fflush(stdout);
    
    frame_cnt++;
    
    return pkt;
}

@end
