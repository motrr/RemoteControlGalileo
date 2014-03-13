#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <set>

@protocol CameraInputDelegate

@required
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

    std::set<__weak id<CameraInputDelegate> > mNotifiers;
}

- (void)addNotifier:(id<CameraInputDelegate>)notifier;
- (void)removeNotifier:(id<CameraInputDelegate>)notifier;

- (void)startCapture;
- (bool)isRunning;

@end
