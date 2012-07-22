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
    unsigned char* y_plane;
    unsigned char* u_plane;
    unsigned char* v_plane;
    
}

- (CVPixelBufferRef) decodeFrameData: (NSData*) data;

@end
