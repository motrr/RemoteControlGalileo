#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol CameraInputDelegate

- (void)didCaptureFrame:(CVPixelBufferRef)pixelBuffer; 

@end

@interface CameraInput : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    bool hasBeganCapture;
    
    // AVCapture vars
    AVCaptureSession *captureSession;
    AVCaptureDeviceInput *videoCaptureInput;
    AVCaptureVideoDataOutput *videoDataOutput;
    
    // Quality vars
    NSString *videoQuality; 
    
   // Queues on which video frames are proccessed
    dispatch_queue_t captureAndEncodingQueue;
}

@property(nonatomic, weak) id delegate;

- (void)startCapture;
- (bool)isRunning;

@end
