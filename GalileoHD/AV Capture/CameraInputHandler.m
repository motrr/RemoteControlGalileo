//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "CameraInputHandler.h"
#import "VideoCropScaler.h"
#import "VideoTransmitter.h"
#import "VideoRecorder.h"


#define CAPTURE_FRAMES_PER_SECOND   15
#define FORCE_REAR_CAMERA           YES

@implementation CameraInputHandler

- (id) init
{
    if (self = [super init]) {
        
        hasBeganCapture = NO;
        
        // Quality vars
        video_quality = AVCaptureSessionPresetHigh; 
        
        videoTransmitter = [[VideoTransmitter alloc] init];
        videoProcessor = [[VideoCropScaler alloc] initWithTransmitter:videoTransmitter];
        videoRecorder = [[VideoRecorder alloc] init];
    
    }
    return self;
} 

- (void) dealloc
{
    NSLog(@"CameraInput exiting...");
    
    if (hasBeganCapture) {
        // Stop capture
        [captureSession stopRunning];
        dispatch_release(queue);
    }
}


#pragma mark -
#pragma mark VideoConfigResponderDelegate Methods

- (void) ipAddressRecieved:(NSString *)addressString
{
    // Check if socket is already open
    if (hasBeganCapture) return;
    
    // Open a socket using the destination IP address and default port
    [videoTransmitter openSocketWithIpAddress: addressString port: AV_UDP_PORT];
    
    // Begin video capture and transmission
    [self startCapture];
    
}

- (void) zoomLevelUpdateRecieved:(NSNumber *)scaleFactor
{
    videoProcessor.zoomFactor = 1.0 / [scaleFactor floatValue];
}

- (void) startRecording
{
    [videoRecorder startRecording];
}

- (void) stopRecording
{
    [videoRecorder stopRecording];
}


#pragma mark -
#pragma mark AV capture and transmission

// Helper function to return a front facing camera, if one is available
- (AVCaptureDevice *)frontFacingCameraIfAvailable
{
    NSArray * videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *captureDevice = nil;

    // Look at all the video devices and get the first one that's on the front
    if (!FORCE_REAR_CAMERA) {
        for (AVCaptureDevice *device in videoDevices)
        {
            if (device.position == AVCaptureDevicePositionFront)
            {
                captureDevice = device;
                break;
            }
        }
        videoProcessor.cameraOrientation = FRONT_FACING_CAMERA;
    }
    
    // If we couldn't find one on the front, just get the default video device.
    if ( !captureDevice )
    {
        NSLog(@"Couldn't find front facing camera");
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        videoProcessor.cameraOrientation = REAR_FACING_CAMERA;
    }
    
    if (! captureDevice) NSLog( @"Error - couldn't create video capture device" );
    
    return captureDevice;
}

// Helper function to setup the capture connection properties (framerate and flipping)
- (void) setCaptureFramerate: (AVCaptureConnection*) conn
{
    NSLog( @"Setting framerate - about to show min/max duration before and after setting...");
    // Set the framerate
    CMTimeShow(conn.videoMinFrameDuration); // Output initial framerate
    CMTimeShow(conn.videoMaxFrameDuration); //
    
    if (conn.supportsVideoMinFrameDuration)
        conn.videoMinFrameDuration = CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND);
    if (conn.supportsVideoMaxFrameDuration)
        conn.videoMaxFrameDuration = CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND);
    
    CMTimeShow(conn.videoMinFrameDuration); // Check new framerate has been applied here
    CMTimeShow(conn.videoMaxFrameDuration); //
    NSLog( @"...framerate set");
}
/*
- (void) deprecatedSetFramerateTo: (unsigned int) fps
              withInput: (AVCaptureDeviceInput*) captureInput 
              andOutput: (AVCaptureVideoDataOutput*) captureOutput
{
    [captureOutput setMinFrameDuration: CMTimeMake(1, fps)];
    NSLog( @"BEGIN -- frame min duration");
    CMTimeShow(captureOutput.minFrameDuration);
    NSLog( @"END -- frame min duration");
}
*/

// Begin capturing video through a camera
- (void)startCapture
{
    hasBeganCapture = YES;
    
	// Setup AV input
    AVCaptureDevice* front = [self frontFacingCameraIfAvailable];
    NSError *error;
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:front error:&error];
    if (error) NSLog( @"Error - couldn't create video input" );
	
    // Setup AV output
	AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
	captureOutput.alwaysDiscardsLateVideoFrames = YES; 
    
	// Create a serial queue to handle the processing of frames
	queue = dispatch_queue_create("cameraQueue", NULL);
	[captureOutput setSampleBufferDelegate:self queue:queue];
    
	// Set the video output to store frame in BGRA (supposed to be well supported for Core Graphics)
	NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
	NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
	[captureOutput setVideoSettings:videoSettings];
    
    // Create a capture session, add inputs/outputs and set camera quality
	captureSession = [[AVCaptureSession alloc] init];
    if ([captureSession canAddInput:captureInput])
        [captureSession addInput:captureInput];
    else NSLog(@"Error - couldn't add video input");
    if ([captureSession canAddOutput:captureOutput])
        [captureSession addOutput:captureOutput];
    else NSLog(@"Error - couldn't add video output");
    if ([captureSession canSetSessionPreset:video_quality])
        [captureSession setSessionPreset:video_quality];
    
    // Set the framerate through the capture connection
    AVCaptureConnection *videoConnection = [captureOutput connectionWithMediaType:AVMediaTypeVideo];
    [self setCaptureFramerate:videoConnection];
    
	//Begin capture
	[captureSession startRunning];
    
}


#pragma mark -
#pragma mark AVCaptureSession delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
	   fromConnection:(AVCaptureConnection *)connection 
{ 

    // Update the processor with the latest frame
    [videoProcessor setLatestPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer)];
    
    // Push the frame to the video recorder
    [videoRecorder recordSampleBuffer:sampleBuffer fromConnection:connection];
        
    // Queue up a call to process the image frame and send over the UDP socket (OpenGL must be done on the main thread)
    [videoProcessor performSelectorOnMainThread:@selector(processVideoFrame) withObject:nil waitUntilDone:NO];
    
} 


@end
