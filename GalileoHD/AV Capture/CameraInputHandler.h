//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Captures video from the camera and sends it to the network controller.

#import <Foundation/Foundation.h>
#import "GalileoCommon.h"

// AV capture
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#import "OpenGLProcessor.h"

@class Vp8Encoder;
@class Vp8RtpPacketiser;
@class PacketSender;

@class VideoRecorder;


@interface CameraInputHandler : NSObject <VideoConfigResponderDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, OpenGLProcessorOutputDelegate>
{
    Boolean hasBeganCapture;
    
    // Video pipeline objects
    OpenGLProcessor* videoProcessor;
    Vp8Encoder* videoEncoder;
    Vp8RtpPacketiser* videoPacketiser;
    PacketSender* packetSender;
    
    
    // Object for recording frames to storage
    __strong VideoRecorder* videoRecorder;
    
    // AVCapture vars
    AVCaptureSession* captureSession;
    
    // Quality vars
    NSString*     video_quality; 
    
   // Queue on which video frames are proccessed
    dispatch_queue_t queue;

    
}

// Begin/end capturing video through a camera
- (void) startCapture;

@end
