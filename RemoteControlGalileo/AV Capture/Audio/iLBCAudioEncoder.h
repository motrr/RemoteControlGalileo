#ifndef iLBCAudioEncoder_H
#define iLBCAudioEncoder_H

#include "AudioEncoder.h"

#if __cplusplus
extern "C" { 
#endif

#include "iLBC_encode.h"

#if __cplusplus
}
#endif

class iLBCAudioEncoder : public AudioEncoder
{
public:
    iLBCAudioEncoder();
    ~iLBCAudioEncoder();

    virtual bool setup(int sampleRate, int channels, int bitsPerChannel);
    virtual BufferPtr encode(const void *buffer, size_t &size, bool discardFrames);

private:
    iLBC_Enc_Inst_t mEncoder; 

    size_t mMsPerFrame;
    size_t mNumSamplesPerFrame;
    size_t mNumBytesPerFrame;
    uint8_t *mEncodeBuffer;
};

#endif

