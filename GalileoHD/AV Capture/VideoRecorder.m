//  Created by Chris Harding on 14/05/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoRecorder.h"
#import "AssetsLibrary/AssetsLibrary.h"

@implementation VideoRecorder

@synthesize recording;

- (id) init
{
    if (self = [super init]) {
        // Create serial queue for movie writing
        movieWritingQueue = dispatch_queue_create("Movie Writing Queue", DISPATCH_QUEUE_SERIAL);
        
        // Create output URL for video asset
        movieURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"GalileoWifi.mp4"]];

    }
    return self;
}

- (void) dealloc
{
    NSLog(@"VideoRecorder exiting");
    [self stopRecording];
    dispatch_release( movieWritingQueue );
    
}

#pragma mark Recording

- (void) startRecording
{
    dispatch_async(movieWritingQueue, ^{
        
        if ( recordingWillBeStarted || self.recording )
            return;
        
        recordingWillBeStarted = YES;
        
        // recordingDidStart is called from captureOutput:didOutputSampleBuffer:fromConnection: once the asset writer is setup
        //[self.delegate recordingWillStart];
        
        // Remove the file if one with the same name already exists
        [self removeFile:movieURL];
        
        // Create an asset writer
        NSError *error;
        assetWriter = [[AVAssetWriter alloc] initWithURL:movieURL fileType:(NSString *)AVFileTypeMPEG4 error:&error];
        if (error)
            [self showError:error];
    }); 
}

- (void) recordSampleBuffer: (CMSampleBufferRef) sampleBuffer fromConnection: (AVCaptureConnection*) connection
{
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    
	CFRetain(sampleBuffer);
	CFRetain(formatDescription);
	dispatch_async(movieWritingQueue, ^{
        
		if ( assetWriter ) {
            
			BOOL wasReadyToRecord = (readyToRecordVideo);
				
            // Initialize the video input if this is not done yet
            if (!readyToRecordVideo)
                readyToRecordVideo = [self setupAssetWriterVideoInput:formatDescription];
            
            // Write video data to file
            if (readyToRecordVideo)
                [self writeSampleBuffer:sampleBuffer];

			
			BOOL isReadyToRecord = (readyToRecordVideo);
			if ( !wasReadyToRecord && isReadyToRecord ) {
				recordingWillBeStarted = NO;
				self.recording = YES;
				//[self.delegate recordingDidStart];
			}
		}
		CFRelease(sampleBuffer);
		CFRelease(formatDescription);
	});
}

- (BOOL) setupAssetWriterVideoInput:(CMFormatDescriptionRef)currentFormatDescription 
{
    float bitsPerPixel;
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription);
    int numPixels = dimensions.width * dimensions.height;
    int bitsPerSecond;
    
    // Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
    if ( numPixels < (640 * 480) )
        bitsPerPixel = 4.05; // This bitrate matches the quality produced by AVCaptureSessionPresetMedium or Low.
    else
        bitsPerPixel = 11.4; // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
    
    bitsPerSecond = numPixels * bitsPerPixel;
    
    NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              AVVideoCodecH264, AVVideoCodecKey,
                                              [NSNumber numberWithInteger:dimensions.width], AVVideoWidthKey,
                                              [NSNumber numberWithInteger:dimensions.height], AVVideoHeightKey,
                                              [NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
                                               [NSNumber numberWithInteger:30], AVVideoMaxKeyFrameIntervalKey,
                                               nil], AVVideoCompressionPropertiesKey,
                                              nil];
    if ([assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
        assetWriterVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
        assetWriterVideoInput.expectsMediaDataInRealTime = YES;
        assetWriterVideoInput.transform = CGAffineTransformMakeRotation(M_PI);
        if ([assetWriter canAddInput:assetWriterVideoInput])
            [assetWriter addInput:assetWriterVideoInput];
        else {
            NSLog(@"Couldn't add asset writer video input.");
            return NO;
        }
    }
    else {
        NSLog(@"Couldn't apply video output settings.");
        return NO;
    }
    
    return YES;
}

- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    //NSLog(@"Writing sample buffer");
    
    if ( assetWriter.status == AVAssetWriterStatusUnknown ) {
        
        if ([assetWriter startWriting]) {           
            [assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
        }
        else {
            [self showError:[assetWriter error]];
        }
    }
    
    if ( assetWriter.status == AVAssetWriterStatusWriting ) {
        
        if (assetWriterVideoInput.readyForMoreMediaData) {
            if (![assetWriterVideoInput appendSampleBuffer:sampleBuffer]) {
                [self showError:[assetWriter error]];
            }
        }
    }
}

- (void) stopRecording
{
    dispatch_sync(movieWritingQueue, ^{
        
        if ( recordingWillBeStopped || (self.recording == NO) )
            return;
        
        recordingWillBeStopped = YES;
        
        // recordingDidStop is called from saveMovieToCameraRoll
        //[self.delegate recordingWillStop];
        
        if ([assetWriter finishWriting]) {
            assetWriter = nil;
            
            readyToRecordVideo = NO;
            
            [self saveMovieToCameraRoll];
        }
        else {
            [self showError:[assetWriter error]];
        }
    });
}

- (void)saveMovieToCameraRoll
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:movieURL
                                completionBlock:^(NSURL *assetURL, NSError *error) {
                                    if (error)
                                        [self showError:error];
                                    else
                                        [self removeFile:movieURL];
                                    
                                    dispatch_async(movieWritingQueue, ^{
                                        recordingWillBeStopped = NO;
                                        self.recording = NO;
                                        
                                        //[self.delegate recordingDidStop];
                                    });
                                }];
}

- (void)removeFile:(NSURL *)fileURL
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [fileURL path];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *error;
        BOOL success = [fileManager removeItemAtPath:filePath error:&error];
        if (!success)
            [self showError:error];
    }
}

#pragma mark Error Handling

- (void)showError:(NSError *)error
{
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                            message:[error localizedFailureReason]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    });
}

@end
