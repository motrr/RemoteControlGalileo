//  Created by Chris Harding on 14/05/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CMBufferQueue.h>

@interface VideoRecorder : NSObject
{
    NSURL *movieURL;
    AVAssetWriter *assetWriter;
    AVAssetWriterInput *assetWriterVideoInput;
    dispatch_queue_t movieWritingQueue;
    
    // Only accessed on movie writing queue
    BOOL readyToRecordVideo;
    BOOL recordingWillBeStarted;
    BOOL recordingWillBeStopped;
    
}

@property BOOL recording;

- (void) startRecording;
- (void) recordSampleBuffer: (CMSampleBufferRef) sampleBuffer fromConnection: (AVCaptureConnection*) connection;
- (void) stopRecording;

@end
