#import "AudioInputOutput.h"
#import "VideoTxRxCommon.h"

#import "RtpDepacketiser.h"
#include "RtpPacketiser.h"

#include "iLBCAudioEncoder.h"
#include "iLBCAudioDecoder.h"

#include "RingBuffer.h"
#include "FIFOBuffer.h"
#include "AudioDevice.h"
#include <set>

@interface AudioInputOutput ()
{
    RtpDepacketiser *audioDepacketiser;
    RtpPacketiser *audioPacketiser;
    
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

        audioDepacketiser = [[RtpDepacketiser alloc] initWithPort:AUDIO_UDP_PORT payloadDescriptorLength:0];
        audioDepacketiser.delegate = self;

        audioDecoder = new iLBCAudioDecoder();
        audioDecoder->setup();

        // The remainder of the audio streaming pipeline objects
        audioPacketiser = new RtpPacketiser(103);

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
    audioDepacketiser.delegate = nil;

    [audioDepacketiser closeSocket];
    delete audioPacketiser;
    
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
    audioPacketiser->configure(address, AUDIO_UDP_PORT);
    
    //
    audioDevice->start();
    
    // Create socket to listen out for video transmission
    [audioDepacketiser openSocket];

    // Start listening in the background
    [NSThread detachNewThreadSelector:@selector(startListening)
                             toTarget:audioDepacketiser
                           withObject:nil];
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

    // buffer will discard new samples when full
    //recordRingBuffer->push(buffer, length);

    // encode
    /*size_t size = length;
     BufferPtr buffer = audioEncoder->encode(buffer, size, true);
     if(buffer.get())
     {
     }*/

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
            // Send the packet
            void *data = buffer->getData();
            size = buffer->getSize();

            dispatch_async(sendQueue, ^{
                audioPacketiser->sendFrame(data, size, true);
            });

            // clear processed bytes
            recordBuffer->pop(size);
        }

        [recordLock unlock];
    });
}

#pragma mark -
#pragma mark RtpDepacketiserDelegate methods

- (void)processEncodedData:(NSData*)data
{
    BufferPtr buffer = audioDecoder->decode([data bytes], [data length]);
    
    if(buffer.get())
    {
        [playbackLock lock];
        playbackBuffer->push((uint8_t*)buffer->getData(), buffer->getSize());
        [playbackLock unlock];
    }
}

@end