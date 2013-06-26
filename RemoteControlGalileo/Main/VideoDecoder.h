//
//  VideoDecoder.h
//  RemoteControlGalileo
//
//  Created by Chris Harding on 02/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>

// uv stride = y stride / 2, for vpx see yv12config.c
typedef struct YuvBufferStruct
{
    int width;
    int height;
    int stride[3];
    bool fromVpxImage;
    unsigned char *base;
    unsigned char *planes[3]; // YUV
    CVPixelBufferRef buffers[3];
} YuvBuffer;

YuvBuffer *createYuvBufferVpx(void *vpxImage);
YuvBuffer *createYuvBuffer(int width, int height);
void createPixelBuffer(YuvBuffer *buffer);
void freePixelBuffer(YuvBuffer *buffer);
void freeYuvBuffer(YuvBuffer **buffer);

@interface VideoDecoder : NSObject
{
    YuvBuffer *yuvBuffer;
}

- (YuvBuffer*) decodeFrameDataBuffer: (NSData*) data;

@end
