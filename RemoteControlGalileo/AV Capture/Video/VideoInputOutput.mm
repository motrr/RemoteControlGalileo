#import "VideoInputOutput.h"

#include "Vp8VideoDecoder.h"
#include "VideoTxRxCommon.h"
#include "Hardware.h"

#import "RTPSessionEx.h"
#import "Vp8RTPExtension.h"
#import "RTCPAPPVideoDescription.h"
#import "RTCPPingDescription.h"
#import "rtcpapppacket.h"

#define RTCP_APP_NAME_STAT_VIDEO {0, 0, 0, 0}
#define RTCP_APP_NAME_PING {0, 0, 0, 1}
#define RTCP_APP_NAME_PONG {0, 0, 0, 2}

@implementation VideoInputOutput

@synthesize cameraInput = cameraInput;

- (id)init
{
    if(self = [super init])
    {
        sendQueue = dispatch_queue_create("Video send queue", DISPATCH_QUEUE_SERIAL);
        videoProcessQueue = dispatch_queue_create("Video process queue", DISPATCH_QUEUE_SERIAL);
        RTCPSendTimer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(onRTCPSendTimer:) userInfo:nil repeats:YES];

        int width, height, bitrate;
#   ifdef FORCE_LOW_QUALITY
        bool lowPerformanceDevice = true;
#   else 
        // get performance based on device model
        bool lowPerformanceDevice = true;
        Hardware::Model model = Hardware::getModel();
        if(model == Hardware::HM_iPod_5g || (model >= Hardware::HM_iPhone_4s && model <= Hardware::HM_iPhone_5) ||
           (model >= Hardware::HM_iPad_2 && model <= Hardware::HM_iPadMini))
        {
            // high performance device
            lowPerformanceDevice = false;
        }
        
#   endif 
        if(lowPerformanceDevice)
        {
            width = VIDEO_WIDTH_LOW;
            height = VIDEO_HEIGHT_LOW;
            bitrate = TARGET_BITRATE_PER_PIXEL_LOW;
        }
        else
        {
            width = VIDEO_WIDTH;
            height = VIDEO_HEIGHT;
            bitrate = TARGET_BITRATE_PER_PIXEL;
        }
        
        // The video proccessor crops, scales and performs pixel format transforms. The result is passed asynchronously back here, to its delegate
        videoProcessor = [[OpenGLProcessor alloc] init];
        [videoProcessor setOutputWidth:width height:height];
        videoProcessor.delegate = self;
        
        videoEncoder = new Vp8VideoEncoder();
        videoEncoder->setup(width, height, bitrate, MAX_KEYFRAME_INTERVAL);

        videoDecoder = new Vp8VideoDecoder();
        videoDecoder->setup();
    }
    
    return self;
}

- (void)dealloc
{
    [RTCPSendTimer invalidate];
    [cameraInput removeNotifier:self];
    videoProcessor.delegate = nil;
    
    delete videoDecoder;
    delete videoEncoder;
    sendQueue = nil;//if(sendQueue) dispatch_release(sendQueue);
    videoProcessQueue = nil;
}

#pragma mark -

- (void)onRTCPSendTimer:(NSTimer *)timer
{
    // Send stat
    RTCPAPPVideoDescription data;
    memset(&data, 0, sizeof(RTCPAPPVideoDescription));

    data.mPacketsSent = packetsSent;
    data.mVideoHeight = videoFrameHeight;
    data.mVideoWidth = videoFrameWidth;
    data.mVideoBitrate = videoEncoder->getBitrate();

    const uint8_t name[4] = RTCP_APP_NAME_STAT_VIDEO;
    int status = rtpSession->SendRTCPAPPPacket(RTCP_APP_SUBTYPE_VIDEO, name, &data, sizeof(RTCPAPPVideoDescription));
    if(status < 0)
    {
        printf("ERROR: %s\n", jrtplib::RTPGetErrorString(status).c_str());
    }

    // Ping
    [self sendPing];
}

- (void)onRTCPPacket:(jrtplib::RTCPPacket *)packet
{
    // we handle only APP typed packed
    if (packet->GetPacketType() != jrtplib::RTCPPacket::APP)
        return;
    //
    jrtplib::RTCPAPPPacket *appPacket = static_cast<jrtplib::RTCPAPPPacket *>(packet);
    if (!appPacket) return;

    //
    if (appPacket->GetSubType() != RTCP_APP_SUBTYPE_VIDEO)
        return;

    // Is stat packet
    uint8_t name[4] = RTCP_APP_NAME_STAT_VIDEO;
    if (memcmp(appPacket->GetName(), name, 4) == 0 && appPacket->GetAPPDataLength() == sizeof(RTCPAPPVideoDescription))
    {
        RTCPAPPVideoDescription description = *((RTCPAPPVideoDescription *)appPacket->GetAPPData());
        dispatch_async(videoProcessQueue, ^{
            //

            size_t delivered = packetsReceived;
            size_t shouldReceive = description.mPacketsSent;
            float packetLoss = 0.f;
            if (shouldReceive > 0)
                packetLoss = 100.f * (float)delivered / shouldReceive;

            @autoreleasepool {
                NSString * stringToDisplay = [NSString stringWithFormat:@"Video: %ix%i\nBitrate: %u\nLoss: %0.1f%%", description.mVideoWidth, description.mVideoHeight, description.mVideoBitrate, packetLoss];
                [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_VIDEO_RTCP_DATA_UPDATE object:stringToDisplay userInfo:nil];
            }

            packetsReceived = 0;
        });
    }

    // Is ping packet
    uint8_t namePing[4] = RTCP_APP_NAME_PING;
    if (memcmp(appPacket->GetName(), namePing, 4) == 0 && appPacket->GetAPPDataLength() == sizeof(RTCPPingDescription))
    {
        [self onPing:appPacket];
    }

    // Is pong packet
    uint8_t namePong[4] = RTCP_APP_NAME_PONG;
    if (memcmp(appPacket->GetName(), namePong, 4) == 0  && appPacket->GetAPPDataLength() == sizeof(RTCPPingDescription))
    {
        [self onPong:appPacket];
    }
}

- (void)sendPing
{
    //
    pingSendTime = [NSDate date];

    // send latency test packet
    RTCPPingDescription data;
    memset(&data, 0, sizeof(RTCPPingDescription));
    data.mUID = ++pingPacketUID;

    const uint8_t name[4] = RTCP_APP_NAME_PING;
    int status = rtpSession->SendRTCPAPPPacket(RTCP_APP_SUBTYPE_VIDEO, name, &data, sizeof(RTCPPingDescription));
    if(status < 0)
    {
        printf("ERROR: %s\n", jrtplib::RTPGetErrorString(status).c_str());
    }
    else
    {
        printf("sent ping\n");
    }
}

- (void)onPing:(jrtplib::RTCPAPPPacket *)packet
{
    printf("got ping\n");
    // got latency test packet
    // just send it back
    const uint8_t name[4] = RTCP_APP_NAME_PONG;
    int status = rtpSession->SendRTCPAPPPacket(RTCP_APP_SUBTYPE_VIDEO, name, packet->GetAPPData(), packet->GetAPPDataLength());
    if(status < 0)
    {
        printf("ERROR: %s\n", jrtplib::RTPGetErrorString(status).c_str());
    }
}

- (void)onPong:(jrtplib::RTCPAPPPacket *)packet
{
    printf("got pong\n");
    // got latency test packet response
    RTCPPingDescription description = *((RTCPPingDescription *)packet->GetAPPData());
    uint32_t pingPacketUIDBack = description.mUID;
    if (pingPacketUIDBack != pingPacketUID)
    {
        printf("Pong packet is outdated\n");
    }
    else
    {
        NSDate *now = [NSDate date];
        NSTimeInterval latency = [now timeIntervalSinceDate:pingSendTime];

        @autoreleasepool {
            NSString * stringToDisplay = [NSString stringWithFormat:@"Latency: %0.3fsec", latency * 0.5];
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_LATENCY_RTCP_DATA_UPDATE object:stringToDisplay userInfo:nil];
        }
    }

}

#pragma mark - VideoConfigResponderDelegate Methods

- (void)ipAddressRecieved:(NSString *)addressString
{
    // Check if socket is already open
    if([cameraInput isRunning]) return;
    
    // Prepare the packetiser for sending
    std::string address([addressString UTF8String], [addressString length]);

    // Prepare RTP library
    rtpSession = RTPSessionEx::CreateInstance(50, RTP_TIMEBASE * CAPTURE_FRAMES_PER_SECOND, address, VIDEO_UDP_PORT);
    rtpSession->SetRTPExtensionHelper(new Vp8RTPExtensionHelper());
    
    RTPSessionEx::DepacketizerCallback depacketizerCallback(self, @selector(processEncodedData: length:));
    rtpSession->SetDepacketizerCallback(depacketizerCallback);

    RTPSessionEx::RTCPHandleCallback rtcpCallback(self, @selector(onRTCPPacket:));
    rtpSession->SetRTCPHandleCallback(rtcpCallback);

    // Begin video capture and transmission
    packetsSent = 0;
    packetsReceived = 0;
    packetsReceivedAll = 0;
    [cameraInput startCapture];

    // Start sending RTCP packets
    [[NSRunLoop mainRunLoop] addTimer:RTCPSendTimer forMode:NSRunLoopCommonModes];
}

- (void)zoomLevelUpdateRecieved:(NSNumber *)scaleFactor
{
    videoProcessor.zoomFactor = 1.f / [scaleFactor floatValue];
}

#pragma mark -
#pragma mark CameraInputDelegate methods

- (void)didCaptureFrame:(CVPixelBufferRef)pixelBuffer
{
    videoFrameWidth = CVPixelBufferGetWidth(pixelBuffer);
    videoFrameHeight = CVPixelBufferGetHeight(pixelBuffer);

    [videoProcessor processVideoFrameYuv:pixelBuffer];
}

#pragma mark -
#pragma mark OpenGLProcessorOutputDelegate methods

- (void)didProcessFrame:(CVPixelBufferRef)pixelBuffer
{
    // Wait for any packet sending to finish
    //dispatch_sync(sendQueue, ^{});
    
    // Get access to raw pixel data
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    unsigned char *baseAddress = (unsigned char*)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t size = CVPixelBufferGetDataSize(pixelBuffer);
#ifdef USE_SINGLE_PASS_PREPROCESS
    bool interleaved = true;
#else 
    bool interleaved = false;
#endif
    
    bool isKey = false;
    
    BufferPtr buffer = videoEncoder->encodeYUV(baseAddress, size, interleaved, isKey);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    if(buffer.get())
    {
        // Wait for any packet sending to finish
        dispatch_sync(sendQueue, ^{});
    
        // Ensure frame isn't too big
        assert(buffer->getSize() <= MAX_FRAME_LENGTH);
        //printf("Encoded video frame size: %lu\n", buffer->getSize());
        
        void *data = buffer->getData();
        size_t size = buffer->getSize();
        
        // Send the packet
        dispatch_async(sendQueue, ^{
            rtpSession->SendMultiPacket(data, size, isKey ? FLAG_VP8_KEYFRAME : 0);
            ++packetsSent;
        });
    }
}

#pragma mark -
#pragma mark RtpDepacketiserDelegate methods

- (void)processEncodedData:(void *)data length:(size_t)length
{
    NSData *dataAutoreleased = [NSData dataWithBytes:data length:length];

    dispatch_async(videoProcessQueue, ^{

        ++packetsReceived;
        ++packetsReceivedAll;

        // Decode data into a pixel buffer
        YuvBufferPtr yuvBuffer = videoDecoder->decodeYUV((unsigned char*)[dataAutoreleased bytes], [dataAutoreleased length]);
        YuvBuffer *buffer = yuvBuffer.get();

        if(buffer)
        {
            [self.delegate didDecodeYuvBuffer:buffer];
        }
    });
}

@end
