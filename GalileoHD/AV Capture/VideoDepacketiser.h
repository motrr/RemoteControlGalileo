//
//  VideoDepacketiser.h
//  GalileoHD
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class VideoView;
@class VideoDecoder;

@interface VideoDepacketiser : NSObject
{    
    
    // Decoder to decoder frames
    VideoDecoder* videoDecoder;
    
    // AV reception
    NSData* imageData;
}

// Video frames are displayed on this view once decoded
@property (nonatomic, weak) VideoView* viewForDisplayingFrames;

- (void) openSocket;
- (void) startListeningForVideo;
- (void) closeSocket;


@end
