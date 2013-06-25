//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Captures video from the camera and sends it to the network controller.

#import <Foundation/Foundation.h>
#import "GalileoCommon.h"

// AV capture
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

// CoreAudio Public Utility
#include "CAStreamBasicDescription.h"
#include "CAComponentDescription.h"
#include "CAAudioBufferList.h"
#include "AUOutputBL.h"

#include "FIFOBuffer.h"

@class iLBCEncoder;
@class RtpPacketiser;

@interface AudioInputHandler : NSObject <AudioConfigResponderDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
{
    Boolean hasBeganCapture;
    
    // Audio pipeline objects
    RtpPacketiser* audioPacketiser;
    
    // AVCapture vars
    AVCaptureSession* captureSession;
    AVCaptureDeviceInput* audioCaptureInput;
    AVCaptureAudioDataOutput* audioDataOutput;
    
    //
    //AUGraph auGraph;
    //AudioUnit outputAudioUnit;
    AudioUnit converterAudioUnit;
    
    AudioStreamBasicDescription currentInputFormat;
    AudioStreamBasicDescription currentOutputFormat;
    AUOutputBL* outputBufferList;
    
    double currentSampleTime;
    BOOL didSetUpAudioUnits;
    
    FIFOBuffer<uint8_t> *inputBuffer;
    FIFOBuffer<uint8_t> *outputBuffer;
    
   // Queues on which audio frames are proccessed
    dispatch_queue_t captureAndEncodingQueue;
    dispatch_queue_t sendQueue;
    
    
}

// Begin/end capturing audio
- (void) startCapture;

@end
