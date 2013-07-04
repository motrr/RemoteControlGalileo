#import "CameraInput.h"
#include "VideoTxRxCommon.h"

@implementation CameraInput

- (id)init
{
    if(self = [super init])
    {
        hasBeganCapture = false;
        
        // Quality vars
        videoQuality = AVCaptureSessionPresetHigh;
        
        // Create the serial queues
        captureAndEncodingQueue = dispatch_queue_create("Video capture and encoding queue", DISPATCH_QUEUE_SERIAL);   
    }
    
    return self;
}

- (void)dealloc
{
    NSLog(@"CameraInput exiting...");
        
    if(hasBeganCapture)
    {
        // Stop capture
        [captureSession stopRunning];
    }
    
    dispatch_release(captureAndEncodingQueue);
}

- (bool)isRunning
{
    return hasBeganCapture;
}

#pragma mark -
#pragma mark AV capture and transmission

// Helper function to return a front facing camera, if one is available
- (AVCaptureDevice *)frontFacingCameraIfAvailable
{
    AVCaptureDevice *captureDevice = nil;

    // Look at all the video devices and get the first one that's on the front
    if(!FORCE_REAR_CAMERA)
    {
        NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in videoDevices)
        {
            if (device.position == AVCaptureDevicePositionFront)
            {
                captureDevice = device;
                break;
            }
        }
    }
    
    // If we couldn't find one on the front, just get the default video device.
    if(!captureDevice)
    {
        NSLog(@"Couldn't find front facing camera");
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    if(!captureDevice) NSLog( @"Error - couldn't create video capture device" );
    
    return captureDevice;
}

// Helper function to setup the capture connection properties (framerate and flipping)
- (void)setCaptureFramerate:(AVCaptureConnection*)conn
{
    NSLog(@"Setting framerate - about to show min/max duration before and after setting...");
    // Set the framerate
    CMTimeShow(conn.videoMinFrameDuration); // Output initial framerate
    CMTimeShow(conn.videoMaxFrameDuration); //
    
    if(conn.supportsVideoMinFrameDuration)
        conn.videoMinFrameDuration = CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND);
    if(conn.supportsVideoMaxFrameDuration)
        conn.videoMaxFrameDuration = CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND);
    
    CMTimeShow(conn.videoMinFrameDuration); // Check new framerate has been applied here
    CMTimeShow(conn.videoMaxFrameDuration); //
    NSLog(@"...framerate set");
}

- (void)setupVideoOutput
{
    // Setup AV input
    AVCaptureDevice *front = [self frontFacingCameraIfAvailable];
    NSError *error;
    videoCaptureInput = [AVCaptureDeviceInput deviceInputWithDevice:front error:&error];
    if(error) NSLog( @"Error - couldn't create video input" );
    
    // Setup AV output
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];

    // Process frames on the same queue as encoding, then discard late frames. This ensures that the capture session doesn't overwhelm the encoder
    [videoDataOutput setSampleBufferDelegate:self queue:captureAndEncodingQueue];
    videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    
    // Set the video output to store frame in BGRA (supposed to be well supported for Core Graphics)
    NSString *key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
    NSNumber *value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
    [videoDataOutput setVideoSettings:videoSettings];
}

// Begin capturing video through a camera
- (void)startCapture
{
    hasBeganCapture = true;
    
    [self setupVideoOutput];
    
    // Create a capture session, add inputs/outputs and set camera quality
    captureSession = [[AVCaptureSession alloc] init];
    if([captureSession canAddInput:videoCaptureInput])
        [captureSession addInput:videoCaptureInput];
    else NSLog(@"Error - couldn't add video input");
    if([captureSession canAddOutput:videoDataOutput])
        [captureSession addOutput:videoDataOutput];
    else NSLog(@"Error - couldn't add video output");
    if([captureSession canSetSessionPreset:videoQuality])
        [captureSession setSessionPreset:videoQuality];
    
    // Set the framerate through the capture connection
    AVCaptureConnection *videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    [self setCaptureFramerate:videoConnection];
    
    // Begin capture
    [captureSession startRunning];
}

#pragma mark -
#pragma mark AVCaptureSessionDelegate methods

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection 
{
    [self.delegate didCaptureFrame:CMSampleBufferGetImageBuffer(sampleBuffer)];
}

@end
