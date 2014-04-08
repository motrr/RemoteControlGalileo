#import "VideoInputOutput.h"

#include "Vp8VideoEncoder.h"
#include "Vp8VideoDecoder.h"
#include "VideoTxRxCommon.h"
#include "Hardware.h"

#import "RTPSessionEx.h"
#import "Vp8RTPExtension.h"

@implementation VideoInputOutput

@synthesize cameraInput = cameraInput;

- (id)init
{
    if(self = [super init])
    {
        sendQueue = dispatch_queue_create("Video send queue", DISPATCH_QUEUE_SERIAL);

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
    [cameraInput removeNotifier:self];
    videoProcessor.delegate = nil;
    
    delete videoDecoder;
    delete videoEncoder;
    sendQueue = nil;//if(sendQueue) dispatch_release(sendQueue);
}

#pragma mark -
#pragma mark VideoConfigResponderDelegate Methods

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

    // Begin video capture and transmission
    [cameraInput startCapture];
}

- (void)zoomLevelUpdateRecieved:(NSNumber *)scaleFactor
{
    videoProcessor.zoomFactor = 1.f / [scaleFactor floatValue];
}

#pragma mark -
#pragma mark CameraInputDelegate methods

- (void)didCaptureFrame:(CVPixelBufferRef)pixelBuffer
{
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
        });
    }
}

#pragma mark -
#pragma mark RtpDepacketiserDelegate methods

- (void)processEncodedData:(void *)data length:(size_t)length
{
    // todo: wrap with dispatch queue (check if its better)
    
    // Decode data into a pixel buffer
    YuvBufferPtr yuvBuffer = videoDecoder->decodeYUV((unsigned char*)data, length);
    YuvBuffer *buffer = yuvBuffer.get();
    
    if(buffer)
    {
        [self.delegate didDecodeYuvBuffer:buffer];
    }
}

@end
