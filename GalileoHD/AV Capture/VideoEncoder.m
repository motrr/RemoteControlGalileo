//
//  VideoEncoder.m
//  GalileoHD
//
//  Created by Chris Harding on 01/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoEncoder.h"

@implementation VideoEncoder

- (NSData*) frameDataFromPixelBuffer: (CVPixelBufferRef) pixelBuffer
{
    // Create NSData from the frame
    char* base_address = CVPixelBufferGetBaseAddress(pixelBuffer);
    unsigned int num_bytes = CVPixelBufferGetDataSize(pixelBuffer);
    
    NSData *rawData = [NSData dataWithBytes:base_address length:num_bytes];
    return rawData;
}

@end
