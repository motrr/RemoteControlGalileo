//
//  VideoEncoder.h
//  GalileoHD
//
//  Created by Chris Harding on 01/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoEncoder : NSObject

- (NSData*) frameDataFromPixelBuffer: (CVPixelBufferRef) pixelBuffer;

@end
