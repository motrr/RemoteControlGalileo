#import <Foundation/Foundation.h>
#import "GalileoCommon.h"
#import "OpenGLProcessor.h"
#import "CameraInput.h"

#include "Buffer.h"

@class CameraInput;

@protocol VideoInputOutputDelegate

- (void)didDecodeYuvBuffer:(YuvBuffer*)yuvBuffer;

@end

class VideoEncoder;
class VideoDecoder;
class RtpPacketiser;
@class RtpDepacketiser;

@interface VideoInputOutput : NSObject <VideoConfigResponderDelegate, OpenGLProcessorDelegate, CameraInputDelegate>
{
    // Video pipeline objects
    __weak CameraInput *cameraInput;
    OpenGLProcessor *videoProcessor;
    VideoEncoder *videoEncoder;
    VideoDecoder *videoDecoder;
    RtpPacketiser *videoPacketiser;
    RtpDepacketiser *videoDepacketiser;
    
    dispatch_queue_t sendQueue;
}

@property (nonatomic, weak) id delegate;
@property (nonatomic, weak) CameraInput *cameraInput;

@end
