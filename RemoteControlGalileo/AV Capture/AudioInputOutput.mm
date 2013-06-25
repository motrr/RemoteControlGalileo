//
//  VideoDepacketiser.m
//  GalileoHD
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "AudioInputOutput.h"
#import "VideoTxRxCommon.h"

#import "iLBCRtpDepacketiser.h"
#import "RtpPacketiser.h"
#import "PacketSender.h"

#include "FIFOBuffer.h"
#include "AudioDevice.h"

extern "C" {
#include "iLBC_encode.h"
#include "iLBC_decode.h"
}

@interface AudioInputOutput ()
{
    iLBCRtpDepacketiser *audioDepacketiser;
    RtpPacketiser* audioPacketiser;
    dispatch_queue_t sendQueue;
    
    int msPerFrameEnc;
    int numSamplesPerFrameEnc;
    int numBytesPerFrameEnc;
    int msPerFrameDec;
    int numSamplesPerFrameDec;
    int numBytesPerFrameDec;
    
    iLBC_Dec_Inst_t iLBCDecoder;
    iLBC_Enc_Inst_t iLBCEncoder; 
    
    FIFOBuffer<uint8_t> *playbackBuffer;
    FIFOBuffer<uint8_t> *recordBuffer;
    AudioDevice *audioDevice;
    NSLock *lock;
}

@end

@implementation AudioInputOutput

- (id) init
{
    if (self = [super init]) {
        audioDepacketiser = [[iLBCRtpDepacketiser alloc] initWithPort:AUDIO_UDP_PORT];
        audioDepacketiser.delegate = self;
        
        // The remainder of the audio streaming pipeline objects
        sendQueue = dispatch_queue_create("Audio send queue", DISPATCH_QUEUE_SERIAL);
        audioPacketiser = [[RtpPacketiser alloc] initWithPayloadType:103];

        msPerFrameEnc = 20; // possible values 20 or 30
        if(msPerFrameEnc == 20)
        {
            numSamplesPerFrameEnc = BLOCKL_20MS;
            numBytesPerFrameEnc = NO_OF_BYTES_20MS;
        }
        else
        {
            numSamplesPerFrameEnc = BLOCKL_30MS;
            numBytesPerFrameEnc = NO_OF_BYTES_30MS;
        }

        initEncode(&iLBCEncoder, msPerFrameEnc); 
        
        //
        lock = [[NSLock alloc] init];
        playbackBuffer = new FIFOBuffer<uint8_t>();
        recordBuffer = new FIFOBuffer<uint8_t>();
        
        AudioDevice::PlaybackCallback playbackCallback(self, @selector(getPlaybackData: length:));
        AudioDevice::RecordBufferCallback recordBufferCallback(self, @selector(getRecordBuffer:));
        AudioDevice::RecordStatusCallback recordStatusCallback(self, @selector(finishRecordingBuffer:));
        
        audioDevice = new AudioDevice(8000, 1);
        audioDevice->Initialize();
        audioDevice->InitializePlayback(playbackCallback, true);
        audioDevice->InitializeRecord(recordStatusCallback, recordBufferCallback);
    }
    
    return self;
}

- (void) dealloc
{
    [audioDepacketiser closeSocket];
    
    if (audioDevice) delete audioDevice;
    if (recordBuffer) delete recordBuffer;
    if (playbackBuffer) delete playbackBuffer;
}

#pragma mark -
#pragma mark AudioConfigResponderDelegate Methods

- (void) ipAddressRecieved:(NSString *)addressString
{
    // Check if socket is already open
    if (audioDevice->isRunning()) return;

    // Prepare the packetiser for sending
    [audioPacketiser prepareForSendingTo:addressString onPort:AUDIO_UDP_PORT]; // todo: should we use same port for audio/video?
    
    //
    audioDevice->Start();
    
    // Create socket to listen out for video transmission
    [audioDepacketiser openSocket];

    // Start listening in the background
    [NSThread detachNewThreadSelector: @selector(startListening)
                             toTarget: audioDepacketiser
                           withObject: nil];
}

#pragma mark -

- (size_t) getPlaybackData: (void*) data length: (size_t) length
{
    [lock lock];
    size_t size = playbackBuffer->pop((uint8_t*)data, length);
    [lock unlock];
    
    return size;
}

- (void*) getRecordBuffer: (size_t) length
{
    size_t position = recordBuffer->size();
    recordBuffer->push(length);
    
    return recordBuffer->begin() + position;
}

- (void) finishRecordingBuffer: (size_t) unusedLength
{
    recordBuffer->pop(unusedLength);
    
    int bytesPerFrame = numSamplesPerFrameEnc * 2; // input
    float samplesFloat[BLOCKL_MAX];
        
    size_t dataSize = recordBuffer->size();
    int maxFramesPerPacket = 7;
    int framesPerPacket = dataSize / bytesPerFrame;
    bool discardFrames = false;
    if (framesPerPacket > maxFramesPerPacket) { // 
        framesPerPacket = maxFramesPerPacket;
        discardFrames = true;
    } else if (framesPerPacket < 1) {
        // skip
        return;
    }
        
    int16_t *samples = (int16_t*)recordBuffer->begin();
    uint8_t *result = (uint8_t*)malloc(numBytesPerFrameEnc * framesPerPacket);
    uint8_t *resultBytes = result;
    for(int i = 0; i < framesPerPacket; i++) {
        int offset = i * numSamplesPerFrameEnc;
        for(int j = 0; j < numSamplesPerFrameEnc; j++)
            samplesFloat[j] = samples[j + offset];
            
        iLBC_encode(resultBytes, samplesFloat, &iLBCEncoder);
        resultBytes += numBytesPerFrameEnc;
    }
        
    // Wait for any packet sending to finish
    dispatch_sync(sendQueue, ^{});
        
    // Send the packet
    dispatch_async(sendQueue, ^{
        [audioPacketiser sendFrame:result length:numBytesPerFrameEnc * framesPerPacket];
    });
    
    // audioPacketiser will take care of deallocation
    //free(result);
        
    if (discardFrames) {
        recordBuffer->clear();
        printf("Some audio packets was discarded\n");
    } else {
        recordBuffer->pop(bytesPerFrame * framesPerPacket);
    }
}

- (void) processEncodedData: (NSData*) data
{
    int numBytes = [data length];
    uint8_t* bytes = (uint8_t*)[data bytes];
    int16_t samples[BLOCKL_MAX];
    float samplesFloat[BLOCKL_MAX];
    
    if (numBytes % NO_OF_BYTES_20MS != 0 && numBytes % NO_OF_BYTES_30MS != 0) {
        printf("invalid num of bytes for iBLC to decode %d\n", numBytes);
        return;
    }
    
    if (numBytes % NO_OF_BYTES_20MS == 0 && numBytesPerFrameDec != NO_OF_BYTES_20MS) {
        // not yet configured, or misconfigured
        msPerFrameDec = 20;
        numBytesPerFrameDec = NO_OF_BYTES_20MS;
        numSamplesPerFrameDec = BLOCKL_20MS;
        initDecode(&iLBCDecoder, msPerFrameDec, 0);
    } else if (numBytes % NO_OF_BYTES_30MS == 0 && numBytesPerFrameDec != NO_OF_BYTES_30MS) {
        // not yet configured, or misconfigured
        msPerFrameDec = 30;
        numBytesPerFrameDec = NO_OF_BYTES_30MS;
        numSamplesPerFrameDec = BLOCKL_30MS;
        initDecode(&iLBCDecoder, msPerFrameDec, 0);
    }
    
    if (numBytesPerFrameDec > 0 && numBytes >= numBytesPerFrameDec) {
        int framePerPacket = numBytes / numBytesPerFrameDec;

        for (int i = 0; i < framePerPacket; i++) {
            iLBC_decode(samplesFloat, bytes + (i * numBytesPerFrameDec), &iLBCDecoder, 1);
            
            [lock lock];
            for (int j = 0; j < numSamplesPerFrameDec; j++)
                samples[j] = samplesFloat[j];

            playbackBuffer->push((uint8_t*)samples, numSamplesPerFrameDec * sizeof(int16_t));
            [lock unlock];
        }
    }
}

@end