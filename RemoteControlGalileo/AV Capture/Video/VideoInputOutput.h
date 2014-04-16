#import <Foundation/Foundation.h>
#import "GalileoCommon.h"
#import "OpenGLProcessor.h"
#import "CameraInput.h"
#include "Vp9VideoEncoder.h"

#include "Buffer.h"

#define NOTIFICATION_VIDEO_RTCP_DATA_UPDATE @"NOTIFICATION_VIDEO_RTCP_DATA_UPDATE"
#define NOTIFICATION_LATENCY_RTCP_DATA_UPDATE @"NOTIFICATION_LATENCY_RTCP_DATA_UPDATE"

@class CameraInput;

@protocol VideoInputOutputDelegate

- (void)didDecodeYuvBuffer:(YuvBuffer*)yuvBuffer;

@end

class RTPSessionEx;
class VideoEncoder;
class VideoDecoder;
@class RtpDepacketiser;

@interface VideoInputOutput : NSObject <VideoConfigResponderDelegate, OpenGLProcessorDelegate, CameraInputDelegate>
{
    // Video pipeline objects
    __weak CameraInput *cameraInput;
    OpenGLProcessor *videoProcessor;
    Vp9VideoEncoder *videoEncoder;
    VideoDecoder *videoDecoder;

    RTPSessionEx *rtpSession;

    dispatch_queue_t sendQueue;
    dispatch_queue_t videoProcessQueue;

    uint32_t packetsSent;
    uint32_t packetsReceived;
    uint32_t packetsReceivedAll;

    uint32_t pingPacketUID;
    NSDate *pingSendTime;

    NSTimer *RTCPSendTimer;
    size_t videoFrameWidth;
    size_t videoFrameHeight;
}

@property (nonatomic, weak) id delegate;
@property (nonatomic, weak) CameraInput *cameraInput;

@end
