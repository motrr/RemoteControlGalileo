#import "MediaOutput.h"
#import <AVFoundation/AVFoundation.h>

// todo: add autodetect bitrate based on audio sample rate
// note: make sure to adjust bitrate for input audio sample rate
// e.g. audio with sample rate 8000 will never be encoded to AAC with 64k bitrate.

static const int kTimeScale = 1000;
static const int kAudioBitRate = 16000;
static const int kVideoBitRate = 1500000;

@interface MediaOutput ()
{
    AVAssetWriter *mAssetWriter;
    AVAssetWriterInput *mVideoInput;
    AVAssetWriterInput *mAudioInput;
    AVAssetWriterInputPixelBufferAdaptor *mVideoBufferAdaptor;

    CMAudioFormatDescriptionRef mAudioFormatDescription;
    CFAbsoluteTime mStartTime;
    //int _time;
    NSString *videoPath;
}

@end

@implementation MediaOutput

#pragma mark - Memory Management

- (id)init
{
    self = [super init];

    if (self)
    {
        //
    }

    return self;
}

- (void)dealloc
{
    [self stopRecord];
}

#pragma mark - Workflow

- (BOOL)setupWithFilePath:(NSString*)filePath width:(int)width height:(int)height hasAudio:(bool)hasAudio sampleRate:(int)sampleRate channels:(int)channels bitsPerChannel:(UInt32)bitsPerChannel
{
    if (_state == MS_Finalizing)
        return NO;

    videoPath = filePath;
    NSURL *moviePath = [NSURL fileURLWithPath:filePath];

    mAssetWriter = [[AVAssetWriter alloc] initWithURL:moviePath
                                             fileType:AVFileTypeQuickTimeMovie
                                                error:nil];
    [self videoSetupWithSize:CGSizeMake(width, height)];

    if(hasAudio)
        [self audioSetupWithSampleRate:sampleRate channels:channels bitsPerChannel:bitsPerChannel];

    _state = MS_Loaded;

    return YES;
}

- (BOOL)startRecord
{
    if(_state != MS_Loaded)
        return false;

    mStartTime = CFAbsoluteTimeGetCurrent();
    [mAssetWriter startWriting];
    [mAssetWriter startSessionAtSourceTime:kCMTimeZero];

    //_time = 0;
    _state = MS_Running;

    return YES;
}

- (BOOL)stopRecord
{
    if(_state != MS_Running) return NO;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {

        _state = MS_Finalizing;
        if(mVideoInput) [mVideoInput markAsFinished];
        if(mAudioInput) [mAudioInput markAsFinished];

#   if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
        [mAssetWriter finishWritingWithCompletionHandler:^(void)
         {
             printf("Happy end! ^_^");
             [self saveToCameraRoll];
             [self reset];
         }];
#   else
        [mAssetWriter finishWriting];
        [self saveToCameraRoll];
        [self reset];
#   endif
        
    });
    
    return YES;
}

- (void)video:(NSString*)videoPath_ didFinishSavingWithError:(NSError*)error contextInfo:(void*)contextInfo;
{
    if (error)
    {
        NSLog(@"%@",error);
    }
    else
    {
        [[NSFileManager defaultManager] removeItemAtPath:videoPath_ error:0];
    }
}

- (void)saveToCameraRoll
{
    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(videoPath))
    {
        UISaveVideoAtPathToSavedPhotosAlbum(videoPath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }
    else
    {
        NSLog(@"Video file is not compatible with Camera Roll, you can copy it with iTunes from application shared folder");
    }
}

- (void)reset
{
    // is safe to call obj-c methods on nil targets
    _state = MS_Null;
    mVideoInput = nil;
    mAudioInput = nil;
    mVideoBufferAdaptor = nil;
    mAssetWriter = nil;
    if(mAudioFormatDescription) CFRelease(mAudioFormatDescription), mAudioFormatDescription = 0;
}

- (void)videoSetupWithSize:(CGSize)size
{
    int width = size.width;
    int height = size.height;
    NSNumber *videoWidth = [NSNumber numberWithInt:width];
    NSNumber *videoHeight = [NSNumber numberWithInt:height];
    NSDictionary *codecSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInt:kVideoBitRate], AVVideoAverageBitRateKey,
                                   //[NSNumber numberWithInt:1],AVVideoMaxKeyFrameIntervalKey,
                                   //videoCleanApertureSettings, AVVideoCleanApertureKey,
                                   //videoAspectRatioSettings, AVVideoPixelAspectRatioKey,
                                   //AVVideoProfileLevelH264Main30, AVVideoProfileLevelKey,
                                   nil];

    NSDictionary *videoSetting =[NSDictionary dictionaryWithObjectsAndKeys:
                                  AVVideoCodecH264, AVVideoCodecKey,
                                  codecSettings, AVVideoCompressionPropertiesKey,
                                  videoWidth, AVVideoWidthKey,
                                  videoHeight, AVVideoHeightKey,
                                  nil];

    mVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSetting];

    mVideoInput.expectsMediaDataInRealTime = YES;
    if(![mAssetWriter canAddInput:mVideoInput])
    {
        printf("cannot add video output\n");
        _state = MS_Error;
        return;
    }

    [mAssetWriter addInput:mVideoInput];
    mVideoBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:mVideoInput sourcePixelBufferAttributes:nil];
}

- (void)audioSetupWithSampleRate:(int)sampleRate channels:(int)channels bitsPerChannel:(UInt32)bitsPerChannel
{
    //
    AudioChannelLayout channelLayout;
    memset(&channelLayout, 0, sizeof(AudioChannelLayout));
    channelLayout.mChannelLayoutTag = channels > 1 ? kAudioChannelLayoutTag_Stereo : kAudioChannelLayoutTag_Mono;

    NSDictionary *audioSetting = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithUnsignedInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
                                  [NSNumber numberWithInteger:kAudioBitRate], AVEncoderBitRateKey,
                                  [NSNumber numberWithInteger:sampleRate], AVSampleRateKey,
                                  [NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)], AVChannelLayoutKey,
                                  [NSNumber numberWithUnsignedInteger:channels], AVNumberOfChannelsKey,
                                  nil];

    mAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                     outputSettings:audioSetting];
    mAudioInput.expectsMediaDataInRealTime = YES;

    if(![mAssetWriter canAddInput:mAudioInput])
    {
        printf("cannot add audio output\n");
        _state = MS_Error;
        return;
    }

    [mAssetWriter addInput:mAudioInput];

    ///
    if(mAudioFormatDescription) CFRelease(mAudioFormatDescription);

    // audio data format
    AudioStreamBasicDescription audioFormat;
    memset(&audioFormat, 0, sizeof(audioFormat));

    audioFormat.mSampleRate = sampleRate;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = channels;
    audioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mBitsPerChannel = bitsPerChannel;
    audioFormat.mBytesPerFrame = audioFormat.mBitsPerChannel * audioFormat.mChannelsPerFrame / 8;
    audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame * audioFormat.mFramesPerPacket;

    CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &audioFormat,
                                   0, NULL, 0, NULL, NULL,
                                   &mAudioFormatDescription);
}


#pragma mark - CameraInputDelegate

- (void)didCaptureFrame:(CVPixelBufferRef)pixelBuffer
{
    if(_state != MS_Running) return;
    if(!mVideoInput.readyForMoreMediaData)
    {
        printf("Video input is not ready for media data\n");
        return;
    }

    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    CFTimeInterval elapsedTime = currentTime - mStartTime;
    CMTime pts = CMTimeMake(elapsedTime * kTimeScale, kTimeScale);

    if(![mVideoBufferAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:pts])
        NSLog(@"append video frame failed");
}

#pragma mark - AudioInputDelegate

- (void)didReceiveAudioBuffer:(void*)audioBuffer length:(size_t)length
{
    if(_state != MS_Running) return;
    if(!mAudioInput.readyForMoreMediaData)
    {
        //printf("Audio input is not ready for media data\n");
        return;
    }

    // slow way
    assert(mAudioFormatDescription);

    CMBlockBufferRef blockBuffer;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                         audioBuffer,
                                                         length,
                                                         kCFAllocatorNull,
                                                         NULL,
                                                         0,
                                                         length,
                                                         kCMBlockBufferAssureMemoryNowFlag,
                                                         &blockBuffer);

    if(status != noErr)
    {
        printf("CMBlockBufferCreateWithMemoryBlock failed with error %ld\n", status);
        assert(false);
    }

    // copy to new block
    CMBlockBufferRef blockBufferContiguous;
    status = CMBlockBufferCreateContiguous(kCFAllocatorDefault,
                                           blockBuffer,
                                           kCFAllocatorDefault,
                                           NULL,
                                           0,
                                           length,
                                           kCMBlockBufferAssureMemoryNowFlag | kCMBlockBufferAlwaysCopyDataFlag,
                                           &blockBufferContiguous);

    CFRelease(blockBuffer);

    if(status != noErr)
    {
        printf("CMBlockBufferCreateContiguous failed with error %ld\n", status);
        assert(false);
    }

    //
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    CFTimeInterval elapsedTime = currentTime - mStartTime;
    CMTime pts = CMTimeMake(elapsedTime * kTimeScale, kTimeScale);//*/

    /*CMTime pts = CMTimeMake(_time, kTimeScale);
     _time += length * 1000 / (2 * 16000);//*/

    int numSamples = length / 2;

    CMSampleBufferRef sampleBuffer;
    status = CMAudioSampleBufferCreateWithPacketDescriptions(kCFAllocatorDefault,
                                                             blockBufferContiguous,
                                                             YES,
                                                             NULL,
                                                             NULL,
                                                             mAudioFormatDescription,
                                                             numSamples,
                                                             pts,
                                                             NULL,
                                                             &sampleBuffer);

    CFRelease(blockBufferContiguous);

    if(status != noErr)
    {
        printf("CMBlockBufferCreateContiguous failed with error %ld\n", status);
        assert(false);
    }

    //
    if(![mAudioInput appendSampleBuffer:sampleBuffer])
    {
        NSLog(@"append audio frame failed %i %@", mAssetWriter.status, mAssetWriter.error);
    }

    CFRelease(sampleBuffer);
}

@end
