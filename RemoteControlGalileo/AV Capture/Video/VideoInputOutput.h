#import <Foundation/Foundation.h>
#import "GalileoCommon.h"
#import "OpenGLProcessor.h"
#import "CameraInput.h"

#include "Buffer.h"

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
    CameraInput *cameraInput;
    OpenGLProcessor *videoProcessor;
    VideoEncoder *videoEncoder;
    VideoDecoder *videoDecoder;
    RtpPacketiser *videoPacketiser;
    RtpDepacketiser *videoDepacketiser;
    
    dispatch_queue_t sendQueue;
}

@property(nonatomic, weak) id delegate;

@end
