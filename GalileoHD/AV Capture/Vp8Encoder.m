//
//  VideoEncoder.m
//  GalileoHD
//
//  Created by Chris Harding on 01/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "Vp8Encoder.h"
#import "GalileoCommon.h"

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

static void write_ivf_file_header(FILE *outfile,
                                  const vpx_codec_enc_cfg_t *cfg,
                                  int frame_cnt) {
    char header[32];
    
    if(cfg->g_pass != VPX_RC_ONE_PASS && cfg->g_pass != VPX_RC_LAST_PASS)
        return;
    header[0] = 'D';
    header[1] = 'K';
    header[2] = 'I';
    header[3] = 'F';
    mem_put_le16(header+4,  0);                   /* version */
    mem_put_le16(header+6,  32);                  /* headersize */
    mem_put_le32(header+8,  fourcc);              /* headersize */
    mem_put_le16(header+12, cfg->g_w);            /* width */
    mem_put_le16(header+14, cfg->g_h);            /* height */
    mem_put_le32(header+16, cfg->g_timebase.den); /* rate */
    mem_put_le32(header+20, cfg->g_timebase.num); /* scale */
    mem_put_le32(header+24, frame_cnt);           /* length */
    mem_put_le32(header+28, 0);                   /* unused */
    
    if(fwrite(header, 1, 32, outfile));
}


static void write_ivf_frame_header(const vpx_codec_cx_pkt_t *pkt, char* header)
{
    //char             header[12];
    vpx_codec_pts_t  pts;
    
    if(pkt->kind != VPX_CODEC_CX_FRAME_PKT)
        return;
    
    pts = pkt->data.frame.pts;
    mem_put_le32(header, pkt->data.frame.sz);
    mem_put_le32(header+4, pts&0xFFFFFFFF);
    mem_put_le32(header+8, pts >> 32);
    
    //if(fwrite(header, 1, 12, outfile));
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
    unsigned char* base_address = (unsigned char*) CVPixelBufferGetBaseAddress(pixelBuffer);// + UNKNOWN_IMG_OFFSET;
    
    // Alias to planes in source image
    //unsigned char* y_plane_src = base_address;
    //unsigned char* uv_planes = base_address + num_luma_pixels;// + 5*img->w; // Not sure why I have to do this but it works
    
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
    
    /*
    // Copy in the Y values
    memcpy(y_plane_dst, y_plane_src, num_luma_pixels);
    
    // Seperate out the V and U components
    for (unsigned int i = 0; i < num_chroma_pixels; i++) {
        v_plane[i] = uv_planes[2*i];
        u_plane[i] = uv_planes[2*i + 1];
    }
    */
    
    // Run through encoder
    const vpx_codec_cx_pkt_t * pkt = [self encode_frame:img];
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    // Extract frame header from packet
    unsigned char frame_hdr[12];
    write_ivf_frame_header(pkt, (char*)frame_hdr);
    
    // Combine header and frame into one byte stream
    //NSMutableData* frameData = [NSMutableData dataWithBytes:frame_hdr length:12];
    //[frameData appendBytes:pkt->data.frame.buf length:pkt->data.frame.sz];
    NSData* frameData = [NSData dataWithBytes:pkt->data.frame.buf length:pkt->data.frame.sz];
    
    return frameData;
}

- (const vpx_codec_cx_pkt_t *) encode_frame: (vpx_image_t *) raw_img
{
    vpx_codec_iter_t iter = NULL;
    const vpx_codec_cx_pkt_t *pkt;
    
    frame_avail = 1;
    
    if(vpx_codec_encode(&codec, frame_avail? raw_img : NULL, frame_cnt, 1, flags, VPX_DL_REALTIME))
        die_codec(&codec, "Failed to encode frame");
    got_data = 0;
    
    // Sometimes there might be more than one packet, so if you get errors this is why
    pkt = vpx_codec_get_cx_data(&codec, &iter);
    
    got_data = 1;
    switch(pkt->kind) {
        case VPX_CODEC_CX_FRAME_PKT:
            
            // Write header and frame to file
            //write_ivf_frame_header(outfile, pkt);
            //fwrite(pkt->data.frame.buf, 1, pkt->data.frame.sz, outfile);
            
            break;
            
        default:
            printf("WARNING - Got a different kind of packet, don't know how to handle");
            break;
    }
    
    printf(pkt->kind == VPX_CODEC_CX_FRAME_PKT
           && (pkt->data.frame.flags & VPX_FRAME_IS_KEY)? "K":".");
    fflush(stdout);
    
    frame_cnt++;
    
    return pkt;
}

@end
