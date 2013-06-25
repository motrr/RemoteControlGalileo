//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "CameraInputHandler.h"

#import "Vp8Encoder.h"
#import "Vp8RtpPacketiser.h"
#import "PacketSender.h"

@implementation CameraInputHandler

- (id) init
{
    if (self = [super init]) {
        
        hasBeganCapture = NO;
        
        // Quality vars
        videoQuality = AVCaptureSessionPresetHigh;
        
        // Create the serial queues
        captureAndEncodingQueue = dispatch_queue_create("Video capture and encoding queue", DISPATCH_QUEUE_SERIAL);
        sendQueue = dispatch_queue_create("Video send queue", DISPATCH_QUEUE_SERIAL);
        
        // The video proccessor crops, scales and performs pixel format transforms. The result is passed asynchronously back here, to its delegate
        videoProcessor = [[OpenGLProcessor alloc] init];
        videoProcessor.outputDelegate = self;
        
        // The remainder of the video streaming pipeline objects
        videoEncoder = [[Vp8Encoder alloc] init];
        videoPacketiser = [[Vp8RtpPacketiser alloc] initWithPayloadType:96];
    
    }
    return self;
} 

- (void) dealloc
{
    NSLog(@"CameraInput exiting...");
    
    if (hasBeganCapture) {
        // Stop capture
        [captureSession stopRunning];
    }
    
}


#pragma mark -
#pragma mark VideoConfigResponderDelegate Methods

- (void) ipAddressRecieved:(NSString *)addressString
{
    // Check if socket is already open
    if (hasBeganCapture) return;
    
    // Prepare the packetiser for sending
    [videoPacketiser prepareForSendingTo:addressString onPort:VIDEO_UDP_PORT];
    
    // Begin video capture and transmission
    [self startCapture];
    
}

- (void) zoomLevelUpdateRecieved:(NSNumber *)scaleFactor
{
    videoProcessor.zoomFactor = 1.0 / [scaleFactor floatValue];
}


#pragma mark -
#pragma mark AV capture and transmission

// Helper function to return a front facing camera, if one is available
- (AVCaptureDevice *)frontFacingCameraIfAvailable
{
    AVCaptureDevice *captureDevice = nil;

    // Look at all the video devices and get the first one that's on the front
    if (!FORCE_REAR_CAMERA) {
        NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
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
    if (!captureDevice)
    {
        NSLog(@"Couldn't find front facing camera");
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        videoProcessor.cameraOrientation = REAR_FACING_CAMERA;
    }
    
    if (!captureDevice) NSLog( @"Error - couldn't create video capture device" );
    
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

- (void)setupVideoOutput
{
    // Setup AV input
    AVCaptureDevice* front = [self frontFacingCameraIfAvailable];
    NSError *error;
    videoCaptureInput = [AVCaptureDeviceInput deviceInputWithDevice:front error:&error];
    if (error) NSLog( @"Error - couldn't create video input" );
    
    // Setup AV output
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];

    // Process frames on the same queue as encoding, then discard late frames. This ensures that the capture session doesn't overwhelm the encoder
    [videoDataOutput setSampleBufferDelegate:self queue:captureAndEncodingQueue];
    videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    
    // Set the video output to store frame in BGRA (supposed to be well supported for Core Graphics)
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
    [videoDataOutput setVideoSettings:videoSettings];
}

// Begin capturing video through a camera
- (void)startCapture
{
    hasBeganCapture = YES;
    
    [self setupVideoOutput];
    
    // Create a capture session, add inputs/outputs and set camera quality
    captureSession = [[AVCaptureSession alloc] init];
    if ([captureSession canAddInput:videoCaptureInput])
        [captureSession addInput:videoCaptureInput];
    else NSLog(@"Error - couldn't add video input");
    if ([captureSession canAddOutput:videoDataOutput])
        [captureSession addOutput:videoDataOutput];
    else NSLog(@"Error - couldn't add video output");
    if ([captureSession canSetSessionPreset:videoQuality])
        [captureSession setSessionPreset:videoQuality];
    
    // Set the framerate through the capture connection
    AVCaptureConnection *videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    [self setCaptureFramerate:videoConnection];
    
    // Begin capture
    [captureSession startRunning];
    
}


#pragma mark -
#pragma mark AVCaptureSessionDelegate methods

- (void) captureOutput:(AVCaptureOutput *)captureOutput 
 didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
        fromConnection:(AVCaptureConnection *)connection 
{
    [videoProcessor processVideoFrameYuv:CMSampleBufferGetImageBuffer(sampleBuffer)];
}


#pragma mark -
#pragma mark OpenGLProcessorOutputDelegate methods

- (void) handleOutputFrame:(CVPixelBufferRef)outputPixelBuffer
{
    // Wait for any packet sending to finish
    dispatch_sync(sendQueue, ^{});
    
    // Encode the frame using VP8
    NSData* encodedFrame = [videoEncoder frameDataFromYuvPixelBuffer:outputPixelBuffer];
    
    // Send the packet
    dispatch_async(sendQueue, ^{
        [videoPacketiser sendFrame:encodedFrame];
    });
}

@end
