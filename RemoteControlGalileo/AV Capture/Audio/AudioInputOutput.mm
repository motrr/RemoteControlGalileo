#import "AudioInputOutput.h"
#import "VideoTxRxCommon.h"

#include "iLBCAudioEncoder.h"
#include "iLBCAudioDecoder.h"

#include "RingBuffer.h"
#include "FIFOBuffer.h"
#include "AudioDevice.h"
#include <set>

#import "RTPSessionEx.h"

@interface AudioInputOutput ()
{
    RTPSessionEx *rtpSession;

    AudioEncoder *audioEncoder;
    AudioDecoder *audioDecoder;
    dispatch_queue_t sendQueue;
    dispatch_queue_t encodeQueue;

    RingBuffer *recordRingBuffer;
    FIFOBuffer<uint8_t> *playbackBuffer;
    FIFOBuffer<uint8_t> *recordBuffer;
    AudioDevice *audioDevice;
    NSLock *playbackLock;
    NSLock *recordLock;

    std::set<__weak id<AudioInputDelegate> > mNotifiers;
    void *mBuffer;
    size_t mLenght;
}

@end

@implementation AudioInputOutput

- (id)init
{
    if(self = [super init])
    {
        sendQueue = dispatch_queue_create("Audio send queue", DISPATCH_QUEUE_SERIAL);
        encodeQueue = dispatch_queue_create("Audio encode queue", DISPATCH_QUEUE_SERIAL);

        audioDecoder = new iLBCAudioDecoder();
        audioDecoder->setup();

        // The remainder of the audio streaming pipeline objects

        int sampleRate = 8000;
        audioEncoder = new iLBCAudioEncoder();
        audioEncoder->setup(sampleRate, 1, 16);

        //
        playbackLock = [[NSLock alloc] init];
        recordLock = [[NSLock alloc] init];
        playbackBuffer = new FIFOBuffer<uint8_t>();
        recordBuffer = new FIFOBuffer<uint8_t>();
        recordRingBuffer = new RingBuffer(65536, 1); // lets have 64k ring buffer

        AudioDevice::PlaybackCallback playbackCallback(self, @selector(getPlaybackData: length:));
        AudioDevice::RecordBufferCallback recordBufferCallback(self, @selector(getRecordBuffer:));
        AudioDevice::RecordStatusCallback recordStatusCallback(self, @selector(finishRecordingBuffer: length: unusedLength:));

        audioDevice = new AudioDevice(sampleRate, 1, 16);
        audioDevice->initialize();
        audioDevice->initializePlayback(playbackCallback, true);
        audioDevice->initializeRecord(recordStatusCallback, recordBufferCallback);
    }

    return self;
}

- (void)dealloc
{
    delete audioEncoder;
    delete audioDecoder;
    
    delete audioDevice;
    delete recordRingBuffer;
    delete recordBuffer;
    delete playbackBuffer;
    if(sendQueue) sendQueue = 0;//dispatch_release(sendQueue);
    if(encodeQueue) encodeQueue = 0;//dispatch_release(encodeQueue);
}

#pragma mark -
#pragma mark AudioConfigResponderDelegate Methods

- (void)ipAddressRecieved:(NSString *)addressString
{
#ifdef HAS_AUDIO_STREAMING
    // Check if socket is already open
    if(audioDevice->isRunning()) return;

    // Prepare the packetiser for sending
    std::string address([addressString UTF8String], [addressString length]);

    // Prepare RTP library
    rtpSession = RTPSessionEx::CreateInstance(50, 20000, address, AUDIO_UDP_PORT);

    RTPSessionEx::DepacketizerCallback depacketizerCallback(self, @selector(processEncodedData: length:));
    rtpSession->SetDepacketizerCallback(depacketizerCallback);

    // Begin video capture and transmission

    //
    audioDevice->start();
#endif
}

#pragma mark -
#pragma mark AV capture and transmission

- (void)addNotifier:(id<AudioInputDelegate>)notifier
{
    if(mNotifiers.find(notifier) == mNotifiers.end())
        mNotifiers.insert(notifier);
}

- (void)removeNotifier:(id<AudioInputDelegate>)notifier
{
    if(mNotifiers.find(notifier) == mNotifiers.end())
        mNotifiers.erase(notifier);
}

#pragma mark -

- (size_t)getPlaybackData:(void*)data length:(size_t)length
{
    [playbackLock lock];
    size_t size = playbackBuffer->pop((uint8_t*)data, length);
    [playbackLock unlock];
    
    return size;
}

- (void*)getRecordBuffer:(size_t)length
{
//    return 0;
    [recordLock lock];
    size_t position = recordBuffer->size();
    recordBuffer->push(length);

    return recordBuffer->begin() + position;//*/
}


- (void)finishRecordingBuffer:(void*)buffer length:(size_t)length unusedLength:(size_t)unusedLength
{
    // send buffer for recording
    std::set<__weak id<AudioInputDelegate> >::iterator it = mNotifiers.begin();
    std::set<__weak id<AudioInputDelegate> >::iterator iend = mNotifiers.end();
    for(; it != iend; ++it)
    {
        id<AudioInputDelegate> notifier = (*it);
        [notifier didReceiveAudioBuffer:buffer length:length];
    }

    //
    recordBuffer->pop(unusedLength);
    [recordLock unlock];

    dispatch_async(encodeQueue, ^{

        // Wait for any packet sending to finish
        dispatch_sync(sendQueue, ^{});

        [recordLock lock];
        size_t size = recordBuffer->size();
        BufferPtr buffer = audioEncoder->encode(recordBuffer->begin(), size, true);

        if(buffer.get())
        {
            // clear processed bytes
            recordBuffer->pop(size);

            // Send the packet
            void *data = buffer->getData();
            size = buffer->getSize();

            dispatch_async(sendQueue, ^{
                rtpSession->SendMultiPacket(data, size,  1);
            });

        }

        [recordLock unlock];
    });
}

#pragma mark -
#pragma mark RtpDepacketiserDelegate methods

- (void)processEncodedData:(void *)data length:(size_t)length
{
    BufferPtr buffer = audioDecoder->decode(data, length);

    if(buffer.get())
    {
        [playbackLock lock];
        playbackBuffer->push((uint8_t*)buffer->getData(), buffer->getSize());
        [playbackLock unlock];
    }
}

@end