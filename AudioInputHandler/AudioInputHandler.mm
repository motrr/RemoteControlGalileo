//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "AudioInputHandler.h"

//#import "Vp8Encoder.h"
#import "RtpPacketiser.h"
#import "PacketSender.h"

extern "C" {
#include "iLBC_encode.h"
}

static OSStatus PushCurrentInputBufferIntoAudioUnit(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                                    const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                                                    UInt32 inNumberFrames, AudioBufferList *ioData);
                                                    
@interface AudioInputHandler ()
{
    int msPerFrame;
    int numSamplesPerFrame;
    int numBytesPerFrame;
    iLBC_Enc_Inst_t iLBCEncoder;
}

@end

@implementation AudioInputHandler

- (id) init
{
    if (self = [super init]) {

        hasBeganCapture = NO;

        // Create the serial queues
        captureAndEncodingQueue = dispatch_queue_create("Audio capture and encoding queue", DISPATCH_QUEUE_SERIAL);
        sendQueue = dispatch_queue_create("Audio send queue", DISPATCH_QUEUE_SERIAL);

        // The remainder of the audio streaming pipeline objects
        audioPacketiser = [[RtpPacketiser alloc] initWithPayloadType:103];

        msPerFrame = 20; // possible values 20 or 30
        if(msPerFrame == 20)
        {
            numSamplesPerFrame = BLOCKL_20MS;
            numBytesPerFrame = NO_OF_BYTES_20MS;
        }
        else
        {
            numSamplesPerFrame = BLOCKL_30MS;
            numBytesPerFrame = NO_OF_BYTES_30MS;
        }

        initEncode(&iLBCEncoder, msPerFrame);
        
        inputBuffer = new FIFOBuffer<uint8_t>();
        outputBuffer = new FIFOBuffer<uint8_t>();
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"AudioInput exiting...");

    if (hasBeganCapture) {
        // Stop capture
        [captureSession stopRunning];
    }
    
    if (converterAudioUnit) {
        if (didSetUpAudioUnits)
            AudioUnitUninitialize(converterAudioUnit);
            //AUGraphUninitialize(auGraph);
        AudioComponentInstanceDispose(converterAudioUnit);
        //DisposeAUGraph(auGraph);
    }
    
    if (outputBufferList) delete outputBufferList;
    if (outputBuffer) delete outputBuffer;
    if (inputBuffer) delete inputBuffer;
}


#pragma mark -
#pragma mark AudioConfigResponderDelegate Methods

- (void) ipAddressRecieved:(NSString *)addressString
{
    // Check if socket is already open
    if (hasBeganCapture) return;

    // Prepare the packetiser for sending
    [audioPacketiser prepareForSendingTo:addressString onPort:AUDIO_UDP_PORT]; // todo: should we use same port for audio/video?

    // Begin video capture and transmission
    [self startCapture];

}

- (void)setupAudioOutput
{
    // Find the current default audio input device
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];

    if (!audioDevice || !audioDevice.connected) NSLog(@"AVCaptureDevice defaultDeviceWithMediaType failed or device not connected!");

    // Create and add a device input for the audio device to the session
    NSError *error = nil;
    audioCaptureInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (!audioCaptureInput) NSLog(@"AVCaptureDeviceInput allocation failed! %@", [error localizedDescription]);

    // Create and add a AVCaptureAudioDataOutput object to the session
    audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    if (!audioDataOutput) NSLog(@"Could not create AVCaptureAudioDataOutput!");

    [audioDataOutput setSampleBufferDelegate:self queue:captureAndEncodingQueue];

    // setup converter
    CAComponentDescription converterDescription(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter, kAudioUnitManufacturer_Apple);
    AudioComponent component = AudioComponentFindNext(NULL, &converterDescription);
    if(AudioComponentInstanceNew(component, &converterAudioUnit) != noErr)
        NSLog(@"Error - couldn't create audio converter component");

    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = PushCurrentInputBufferIntoAudioUnit; // Render function
    callbackStruct.inputProcRefCon = (void*)inputBuffer;
    if(AudioUnitSetProperty(converterAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(AURenderCallbackStruct)) != noErr)
        NSLog(@"Error - couldn't set callback for audio converter component");//*/
    
    // Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
    /*UInt32 flag = 0;
    if(AudioUnitSetProperty(converterAudioUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, kInputBus, &flag, sizeof(flag));*/
        
    /*AUNode outputNode;
    AUNode converterNode;
    
    // create a new AUGraph
    OSStatus err = NewAUGraph(&auGraph);
    if (err) { printf("NewAUGraph Failed! %ld %08X %4.4s\n", (long)err, (unsigned int)err, (char*)&err); }
    
    CAComponentDescription outputDescription(kAudioUnitType_Output, kAudioUnitSubType_GenericOutput, kAudioUnitManufacturer_Apple);
    CAComponentDescription converterDescription(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter, kAudioUnitManufacturer_Apple);
    
    // add nodes to graph
    err = AUGraphAddNode(auGraph, &outputDescription, &outputNode);
    if (err) { printf("AUGraphNewNode 2 result %lu %4.4s\n", (unsigned long)err, (char*)&err); }
    
    err = AUGraphAddNode(auGraph, &converterDescription, &converterNode);
    if (err) { printf("AUGraphNewNode 3 result %lu %4.4s\n", (unsigned long)err, (char*)&err); }
    
    // connect a node's output to a node's input
    // au converter -> output
    
    err = AUGraphConnectNodeInput(auGraph, converterNode, 0, outputNode, 0);
    if (err) { printf("AUGraphConnectNodeInput result %lu %4.4s\n", (unsigned long)err, (char*)&err); }
    
    // open the graph -- AudioUnits are open but not initialized (no resource allocation occurs here)
    err = AUGraphOpen(auGraph);
    if (err) { printf("AUGraphOpen result %ld %08X %4.4s\n", (long)err, (unsigned int)err, (char*)&err); }
    
    // grab audio unit instances from the nodes
    err = AUGraphNodeInfo(auGraph, converterNode, NULL, &converterAudioUnit);
    if (err) { printf("AUGraphNodeInfo result %ld %08X %4.4s\n", (long)err, (unsigned int)err, (char*)&err); }

    err = AUGraphNodeInfo(auGraph, outputNode, NULL, &outputAudioUnit);
    if (err) { printf("AUGraphNodeInfo result %ld %08X %4.4s\n", (long)err, (unsigned int)err, (char*)&err); }

    // Set a callback on the converter audio unit that will supply the audio buffers received from the capture audio data output
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = PushCurrentInputBufferIntoAudioUnit;
    renderCallbackStruct.inputProcRefCon = (void*)inputBuffer;
    err = AUGraphSetNodeInputCallback(auGraph, converterNode, 0, &renderCallbackStruct);
    if (err) { printf("AUGraphSetNodeInputCallback result %ld %08X %4.4s\n", (long)err, (unsigned int)err, (char*)&err); }//*/
}

// Begin capturing video through a camera
- (void)startCapture
{
    hasBeganCapture = YES;

    [self setupAudioOutput];

    // Create a capture session, add inputs/outputs
    captureSession = [[AVCaptureSession alloc] init];
    if ([captureSession canAddInput:audioCaptureInput])
        [captureSession addInput:audioCaptureInput];
    else NSLog(@"Error - couldn't add audio input");
    if ([captureSession canAddOutput:audioDataOutput])
        [captureSession addOutput:audioDataOutput];
    else NSLog(@"Error - couldn't add audio output");

    // Begin capture
    //[captureSession startRunning];

}


#pragma mark -
#pragma mark AVCaptureAudioDataOutputSampleBufferDelegate methods

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    OSStatus err = noErr;

    // Get the sample buffer's AudioStreamBasicDescription which will be used to set the input format of the audio unit and ExtAudioFile
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    CAStreamBasicDescription sampleBufferFormat(*CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription));
    if (kAudioFormatLinearPCM != sampleBufferFormat.mFormatID) { NSLog(@"Bad format!"); return; }

    if ((sampleBufferFormat.mChannelsPerFrame != currentInputFormat.mChannelsPerFrame) || (sampleBufferFormat.mSampleRate != currentInputFormat.mSampleRate)) {
        NSLog(@"AVCaptureAudioDataOutput Audio Format:");
        sampleBufferFormat.Print();
        // Although in iOS AVCaptureAudioDataOutput as of iOS 6 will output 16-bit PCM only by default, the sample rate will depend on the hardware and the
        // current route and whether you've got any 30-pin audio microphones plugged in and so on. By default, you'll get mono and AVFoundation will request 44.1 kHz,
        // but if the audio route demands a lower sample rate, AVFoundation will deliver that instead. Some 30-pin devices present a stereo stream,
        // in which case AVFoundation will deliver stereo. If there is a change for input format after initial setup, the audio units receiving the buffers needs
        // to be reconfigured with the new format. This also must be done when a buffer is received for the first time.
        currentInputFormat = sampleBufferFormat;

        if (didSetUpAudioUnits) {
            // The audio units were previously set up, so they must be uninitialized now
            err = AudioUnitUninitialize(converterAudioUnit);
            //err = AUGraphUninitialize(auGraph);
            NSLog(@"AudioUnitInitialize failed (%ld)", (long)err);

            inputBuffer->clear();
            outputBuffer->clear();
            if (outputBufferList) delete outputBufferList;
            outputBufferList = NULL;
        } else {
            didSetUpAudioUnits = YES;
        }

        // set the input stream format, this is the format of the audio for the converter input bus
        err = AudioUnitSetProperty(converterAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &currentInputFormat, sizeof(currentInputFormat));
        if (err != noErr)
            NSLog(@"Error - couldn't set input format for audio converter component");
            
        // setup output format
        CAStreamBasicDescription outputFormat(8000, 1, CAStreamBasicDescription::kPCMFormatInt16, false);
        currentOutputFormat = outputFormat;
        err = AudioUnitSetProperty(converterAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &currentOutputFormat, sizeof(currentOutputFormat));
        if (err != noErr)
            NSLog(@"Error - couldn't set output format for audio converter component");
            
        /*err = AudioUnitSetProperty(outputAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &currentOutputFormat, sizeof(currentOutputFormat));
        if (err != noErr)
            NSLog(@"Error - couldn't set output format for output component");//*/
            
        NSLog(@"Output converter format:");
        outputFormat.Print();

        // Initialize the graph
        err = AudioUnitInitialize(converterAudioUnit);
        //err = AUGraphInitialize(auGraph);

        if (err != noErr) {
            NSLog(@"Error - Failed to set up audio unit (%ld)", (long)err);

            didSetUpAudioUnits = NO;
            bzero(&currentInputFormat, sizeof(currentInputFormat));
        }
    }

    CMItemCount numberOfFrames = CMSampleBufferGetNumSamples(sampleBuffer); // corresponds to the number of CoreAudio audio frames

    // In order to render continuously, the effect audio unit needs a new time stamp for each buffer
    // Use the number of frames for each unit of time continuously incrementing
    currentSampleTime += (double)numberOfFrames;

    AudioTimeStamp timeStamp;
    memset(&timeStamp, 0, sizeof(AudioTimeStamp));
    timeStamp.mSampleTime = currentSampleTime;
    timeStamp.mFlags |= kAudioTimeStampSampleTimeValid;

    AudioUnitRenderActionFlags flags = 0;

    // Create an output AudioBufferList as the destination for the AU rendered audio
    if (!outputBufferList) {
        outputBufferList = new AUOutputBL(currentOutputFormat, numberOfFrames);
    }
    outputBufferList->Prepare(numberOfFrames);

    // Get an audio buffer list from the sample buffer and assign it to the currentInputAudioBufferList instance variable.
    // The the audio unit render callback called PushCurrentInputBufferIntoAudioUnit can access this value by calling the
    // currentInputAudioBufferList method.
    // CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer requires a properly allocated AudioBufferList struct
    AudioBufferList *inputAudioBufferList = CAAudioBufferList::Create(currentInputFormat.mChannelsPerFrame);

    size_t bufferListSizeNeededOut;
    CMBlockBufferRef blockBufferOut = nil;

    err = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                                                                  &bufferListSizeNeededOut,
                                                                  inputAudioBufferList,
                                                                  CAAudioBufferList::CalculateByteSize(currentInputFormat.mChannelsPerFrame),
                                                                  kCFAllocatorSystemDefault,
                                                                  kCFAllocatorSystemDefault,
                                                                  kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                  &blockBufferOut);
    
    if (err == noErr) {
        // Fill the input buffer
        int bufferCount = inputAudioBufferList->mNumberBuffers;
        for (int bufferIndex = 0; bufferIndex < bufferCount; bufferIndex++) {
            AudioBuffer &buffer = inputAudioBufferList->mBuffers[bufferIndex];
            if (buffer.mDataByteSize > 0) inputBuffer->push((uint8_t*)buffer.mData, buffer.mDataByteSize);
        }
        
        unsigned int formatSize = 2; // kPCMFormatInt16 == 2 bytes
        unsigned int outputFrames = inputBuffer->size() * currentOutputFormat.mSampleRate / currentInputFormat.mSampleRate / formatSize;
        if (outputFrames > 0) {
            // Tell the effect audio unit to render -- This will synchronously call PushCurrentInputBufferIntoAudioUnit, which will
            // feed currentInputAudioBufferList into the effect audio unit
            err = AudioUnitRender(converterAudioUnit, &flags, &timeStamp, 0, outputFrames, outputBufferList->ABL());
            if (err) {
                // kAudioUnitErr_TooManyFramesToProcess may happen on a route change if CMSampleBufferGetNumSamples
                // returns more than 1024 (the default) number of samples. This is ok and on the next cycle this error should not repeat
                NSLog(@"AudioUnitRender failed! (%ld)", err);
                printf("Audio input was discarded\n");
                inputBuffer->clear();
            } else {
                // Fill in output buffer
                AudioBufferList *bufferList = outputBufferList->ABL();
                int bufferCount = bufferList->mNumberBuffers;
                for (int bufferIndex = 0; bufferIndex < bufferCount; bufferIndex++) {
                    AudioBuffer &buffer = bufferList->mBuffers[bufferIndex];
                    if (buffer.mDataByteSize > 0) outputBuffer->push((uint8_t*)buffer.mData, buffer.mDataByteSize);
                }
            }
        }

        CFRelease(blockBufferOut);
    } else {
        NSLog(@"CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer failed! (%ld)", (long)err);
    }
    
    //
    CAAudioBufferList::Destroy(inputAudioBufferList);

    if (err == noErr) {
        int bytesPerFrame = numSamplesPerFrame * 2; // input
        float samplesFloat[BLOCKL_MAX];
        
        size_t dataSize = outputBuffer->size();
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
        
        int16_t *samples = (int16_t*)outputBuffer->begin();
        uint8_t *result = (uint8_t*)malloc(numBytesPerFrame * framesPerPacket);
        uint8_t *resultBytes = result;
        for(int i = 0; i < framesPerPacket; i++) {
            int offset = i * numSamplesPerFrame;
            for(int j = 0; j < numSamplesPerFrame; j++)
                samplesFloat[j] = samples[j + offset];
            
            iLBC_encode(resultBytes, samplesFloat, &iLBCEncoder);
            resultBytes += numBytesPerFrame;
        }
        
        // Wait for any packet sending to finish
        dispatch_sync(sendQueue, ^{});
        
        // Send the packet
        dispatch_async(sendQueue, ^{
            [audioPacketiser sendFrame:result length:numBytesPerFrame * framesPerPacket];
        });
    
        // audioPacketiser will take care of deallocation
        //free(result);
        
        if (discardFrames) {
            outputBuffer->clear();
            printf("Some audio packets was discarded\n");
        } else {
            outputBuffer->pop(bytesPerFrame * framesPerPacket);
        }
    }
}

@end


#pragma mark -
#pragma mark AudioUnit render callback

// Synchronously called by the effect audio unit whenever AudioUnitRender() is called.
// Used to feed the audio samples output by the ATCaptureAudioDataOutput to the AudioUnit.
static OSStatus PushCurrentInputBufferIntoAudioUnit(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                                    const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                                                    UInt32 inNumberFrames, AudioBufferList *ioData)
{
    FIFOBuffer<uint8_t> *inputAudioBufferList = (FIFOBuffer<uint8_t>*)inRefCon;
    UInt32 bufferIndex, bufferCount = ioData->mNumberBuffers;

    if (bufferCount != 1) return kAudioFormatUnknownFormatError; // support only 1 buffer
    
    // Fill the provided AudioBufferList with the data from the inputAudioBufferList
    for (bufferIndex = 0; bufferIndex < bufferCount; bufferIndex++) {
        size_t numSamples = ioData->mBuffers[bufferIndex].mDataByteSize;
        size_t size = inputAudioBufferList->pop((uint8_t*)ioData->mBuffers[bufferIndex].mData, numSamples);
        assert(size == numSamples);
        
        ioData->mBuffers[bufferIndex].mNumberChannels = 1; // support only mono for now
    }

    return noErr;
}
