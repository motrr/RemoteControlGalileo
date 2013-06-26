//
//  VideoDepacketiser.m
//  RemoteControlGalileo
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "Vp8RtpDepacketiser.h"
#import "VideoTxRxCommon.h"

#import "VideoDecoder.h"
#import "VideoView.h"

@implementation Vp8RtpDepacketiser

- (id) initWithPort: (u_short) inputPort
{
    if (self = [super initWithPort:inputPort payloadDescriptorLength:sizeof(Vp8PayloadDescriptorStruct)]) {
        videoDecoder = [[VideoDecoder alloc] init]; 
    }
    
    return self;
}

- (void) insertPacketIntoFrame: (char*) payload payloadDescriptor:(char*) payload_descriptor 
                 payloadLength: (unsigned int) payload_length markerSet: (Boolean) marker
{
    //Vp8PayloadDescriptorStruct *vp8_payload_descriptor = (Vp8PayloadDescriptorStruct*)payload_descriptor;
    
    //
    [super insertPacketIntoFrame:payload payloadDescriptor:payload_descriptor payloadLength:payload_length markerSet:marker];
}


- (void) processEncodedData: (NSData*) data
{
    // Decode data into a pixel buffer
    YuvBuffer *yuvBuffer = [videoDecoder decodeFrameDataBuffer:data];
    
    if(yuvBuffer)
    {
        // Render the pixel buffer using OpenGL on main thread
        dispatch_queue_t mainQueue = dispatch_get_main_queue();
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_async(group, mainQueue, ^{
            [self.viewForDisplayingFrames renderYuvBuffer:yuvBuffer];
        });
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        dispatch_release(group);
        
        // Cleanup
        //CVPixelBufferRelease(pixelBuffer);
    }
}


@end
