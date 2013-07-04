#include "iLBCAudioDecoder.h"

const int MaxFramesPerPacket = 7;

iLBCAudioDecoder::iLBCAudioDecoder():
    mNumBytesPerFrame(0),
    mDecodeBuffer(0)
{
}

iLBCAudioDecoder::~iLBCAudioDecoder()
{
    delete [] mDecodeBuffer;
}

bool iLBCAudioDecoder::setup()
{
    mDecodeBuffer = new int16_t[BLOCKL_MAX * MaxFramesPerPacket];
    return true;
}

BufferPtr iLBCAudioDecoder::decode(const void *buffer, size_t size)
{
    uint8_t* bytes = (uint8_t*)buffer;
    int16_t *samples = mDecodeBuffer;
    float samplesFloat[BLOCKL_MAX];
    
    if(size % NO_OF_BYTES_20MS != 0 && size % NO_OF_BYTES_30MS != 0)
    {
        printf("invalid num of bytes for iBLC to decode %ld\n", size);
        return BufferPtr();
    }
    
    if(size % NO_OF_BYTES_20MS == 0 && mNumBytesPerFrame != NO_OF_BYTES_20MS)
    {
        // not yet configured, or misconfigured
        mMsPerFrame = 20;
        mNumBytesPerFrame = NO_OF_BYTES_20MS;
        mNumSamplesPerFrame = BLOCKL_20MS;
        initDecode(&mDecoder, mMsPerFrame, 0);
    }
    else if(size % NO_OF_BYTES_30MS == 0 && mNumBytesPerFrame != NO_OF_BYTES_30MS)
    {
        // not yet configured, or misconfigured
        mMsPerFrame = 30;
        mNumBytesPerFrame = NO_OF_BYTES_30MS;
        mNumSamplesPerFrame = BLOCKL_30MS;
        initDecode(&mDecoder, mMsPerFrame, 0);
    }
    
    if(mNumBytesPerFrame > 0 && size >= mNumBytesPerFrame)
    {
        int framePerPacket = size / mNumBytesPerFrame;
        for(int i = 0; i < framePerPacket; i++)
        {
            iLBC_decode(samplesFloat, bytes, &mDecoder, 1);
            
            for (int j = 0; j < mNumSamplesPerFrame; j++)
                samples[j] = samplesFloat[j];

            bytes += mNumBytesPerFrame;
            samples += mNumSamplesPerFrame;
        }
        
        return BufferPtr(new WrapBuffer(mDecodeBuffer, framePerPacket * mNumSamplesPerFrame * 2)); // 16 bit = 2 bytes
    }
    
    return BufferPtr();
}