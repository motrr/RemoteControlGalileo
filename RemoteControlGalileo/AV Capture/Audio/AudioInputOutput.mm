#import "AudioInputOutput.h"
#import "VideoTxRxCommon.h"

#import "RtpDepacketiser.h"
#include "RtpPacketiser.h"

#include "iLBCAudioEncoder.h"
#include "iLBCAudioDecoder.h"

#include "FIFOBuffer.h"
#include "AudioDevice.h"

@interface AudioInputOutput ()
{
    RtpDepacketiser *audioDepacketiser;
    RtpPacketiser *audioPacketiser;
    
    AudioEncoder *audioEncoder;
    AudioDecoder *audioDecoder;
    dispatch_queue_t sendQueue;
    
    FIFOBuffer<uint8_t> *playbackBuffer;
    FIFOBuffer<uint8_t> *recordBuffer;
    AudioDevice *audioDevice;
    NSLock *lock;
}

@end

@implementation AudioInputOutput

- (id)init
{
    if(self = [super init])
    {
        sendQueue = dispatch_queue_create("Audio send queue", DISPATCH_QUEUE_SERIAL);
        
        audioDepacketiser = [[RtpDepacketiser alloc] initWithPort:AUDIO_UDP_PORT payloadDescriptorLength:0];
        audioDepacketiser.delegate = self;
        
        audioDecoder = new iLBCAudioDecoder();
        audioDecoder->setup();
        
        // The remainder of the audio streaming pipeline objects
        audioPacketiser = new RtpPacketiser(103);
        
        audioEncoder = new iLBCAudioEncoder();
        audioEncoder->setup(8000, 1, 16);
        
        //
        lock = [[NSLock alloc] init];
        playbackBuffer = new FIFOBuffer<uint8_t>();
        recordBuffer = new FIFOBuffer<uint8_t>();
        
        AudioDevice::PlaybackCallback playbackCallback(self, @selector(getPlaybackData: length:));
        AudioDevice::RecordBufferCallback recordBufferCallback(self, @selector(getRecordBuffer:));
        AudioDevice::RecordStatusCallback recordStatusCallback(self, @selector(finishRecordingBuffer:));
        
        audioDevice = new AudioDevice(8000, 1, 16);
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
    delete recordBuffer;
    delete playbackBuffer;
    if(sendQueue) dispatch_release(sendQueue);
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

- (size_t)getPlaybackData:(void*)data length:(size_t)length
{
    [lock lock];
    size_t size = playbackBuffer->pop((uint8_t*)data, length);
    [lock unlock];
    
    return size;
}

- (void*)getRecordBuffer:(size_t)length
{
    size_t position = recordBuffer->size();
    recordBuffer->push(length);
    
    return recordBuffer->begin() + position;
}

- (void)finishRecordingBuffer:(size_t)unusedLength
{
    recordBuffer->pop(unusedLength);
    
    // Wait for any packet sending to finish
    dispatch_sync(sendQueue, ^{});
    
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
            audioPacketiser->sendFrame(data, size, true);
        });
    }
}

#pragma mark -
#pragma mark RtpDepacketiserDelegate methods

- (void)processEncodedData:(NSData*)data
{
    BufferPtr buffer = audioDecoder->decode([data bytes], [data length]);
    
    if(buffer.get())
    {
        [lock lock];
        playbackBuffer->push((uint8_t*)buffer->getData(), buffer->getSize());
        [lock unlock];
    }
}

@end