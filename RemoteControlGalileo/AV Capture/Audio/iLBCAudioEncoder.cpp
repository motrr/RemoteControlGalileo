#include "iLBCAudioEncoder.h"

const int MaxFramesPerPacket = 7;

iLBCAudioEncoder::iLBCAudioEncoder():
    mEncodeBuffer(0)
{
}

iLBCAudioEncoder::~iLBCAudioEncoder()
{
    delete [] mEncodeBuffer;
}

bool iLBCAudioEncoder::setup(int sampleRate, int channels, int bitsPerChannel)
{
    if(channels != 1 || bitsPerChannel != 16)
    {
        printf("Can't setup iLBC encoder, invalid input stream\n");
        return false;
    }
    
    mMsPerFrame = 20; // possible values 20 or 30
    if(mMsPerFrame == 20)
    {
        mNumSamplesPerFrame = BLOCKL_20MS;
        mNumBytesPerFrame = NO_OF_BYTES_20MS;
    }
    else
    {
        mNumSamplesPerFrame = BLOCKL_30MS;
        mNumBytesPerFrame = NO_OF_BYTES_30MS;
    }

    initEncode(&mEncoder, mMsPerFrame); 
    mEncodeBuffer = new uint8_t[mNumBytesPerFrame * MaxFramesPerPacket];
    
    return true;
}

BufferPtr iLBCAudioEncoder::encode(const void *buffer, size_t &size, bool discardFrames)
{
    size_t bytesPerFrame = mNumSamplesPerFrame * 2; // 16 bits = 2 bytes
    float samplesFloat[BLOCKL_MAX];
        
    int framesPerPacket = size / bytesPerFrame;
    bool packetsLimitReached = false;
    if(framesPerPacket > MaxFramesPerPacket)
    {
        framesPerPacket = MaxFramesPerPacket;
        packetsLimitReached = true;
    }
    else if(framesPerPacket < 1)
    {
        // skip
        return BufferPtr();
    }
    
    int16_t *samples = (int16_t*)buffer;
    uint8_t *resultBytes = mEncodeBuffer;
    for(int i = 0; i < framesPerPacket; i++)
    {
        for(int j = 0; j < mNumSamplesPerFrame; j++)
            samplesFloat[j] = samples[j];
        
        iLBC_encode(resultBytes, samplesFloat, &mEncoder);
        resultBytes += mNumBytesPerFrame;
        samples += mNumSamplesPerFrame;
    }
    
    if(discardFrames && packetsLimitReached)
    {
        printf("Some audio packets was discarded\n");
        size = bytesPerFrame * (size / bytesPerFrame);
    }
    else
    {
        size = bytesPerFrame * framesPerPacket;
    }
    
    return BufferPtr(new WrapBuffer(mEncodeBuffer, mNumBytesPerFrame * framesPerPacket));
}