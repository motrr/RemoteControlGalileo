//
//  VideoDecoder.h
//  GalileoHD
//
//  Created by Chris Harding on 02/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VideoDecoder : NSObject
{    
    Boolean hasBgraFrameBeenAllocated;
    char* bgra_frame;
}

- (CVPixelBufferRef) decodeFrameData: (NSData*) data;

@end
