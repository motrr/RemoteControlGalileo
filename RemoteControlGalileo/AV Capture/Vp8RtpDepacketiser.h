//
//  VideoDepacketiser.h
//  RemoteControlGalileo
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RtpDepacketiser.h"

@class VideoView;
@class VideoDecoder;

@interface Vp8RtpDepacketiser : RtpDepacketiser
{
    // Decoder to decoder frames
    VideoDecoder* videoDecoder;
}

// Video frames are displayed on this view once decoded
@property (nonatomic, weak) VideoView* viewForDisplayingFrames;

- (id) initWithPort: (u_short) port;

//
- (void) processEncodedData: (NSData*) data;
- (void) insertPacketIntoFrame: (char*) payload payloadDescriptor:(char*) payload_descriptor 
                 payloadLength: (unsigned int) payload_length markerSet: (Boolean) marker;

@end
