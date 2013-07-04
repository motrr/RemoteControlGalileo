#ifndef iLBCAudioDecoder_H
#define iLBCAudioDecoder_H

#include "AudioDecoder.h"

#if __cplusplus
extern "C" { 
#endif

#include "iLBC_decode.h"

#if __cplusplus
}
#endif

class iLBCAudioDecoder : public AudioDecoder
{
public:
    iLBCAudioDecoder();
    ~iLBCAudioDecoder();

    virtual bool setup();
    virtual BufferPtr decode(const void *buffer, size_t size);

private:
    iLBC_Dec_Inst_t mDecoder; 

    size_t mMsPerFrame;
    size_t mNumSamplesPerFrame;
    size_t mNumBytesPerFrame;
    int16_t *mDecodeBuffer;
};

#endif

