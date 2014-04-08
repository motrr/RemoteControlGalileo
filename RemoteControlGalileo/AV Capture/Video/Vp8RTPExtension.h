#ifndef Vp8RTPExtension_H
#define Vp8RTPExtension_H

#include "RTPSessionEx.h"
#include <assert.h>

#define FLAG_VP8_KEYFRAME 1

struct Vp8RTPExtensionHeader : public jrtplib::RTPExtensionHeader
{
    unsigned char extendedControlPresent    : 1;
    unsigned char reserved                  : 1;
    unsigned char nonReferenceFrame         : 1;
    unsigned char partiotionStart           : 1;
    unsigned char partitionId               : 4;
    
    // because extension should be multiply of 32
    uint8_t reserved1;
    uint16_t reserved2;
};

class Vp8RTPExtensionHelper : public RTPExtensionHelper
{
public:
    virtual ~Vp8RTPExtensionHelper() {}
    
    virtual jrtplib::RTPExtensionHeader *getHeader(int packetIndex, unsigned int flags) const
    {
        mExtensionHeader.extendedControlPresent = 0;
        mExtensionHeader.reserved = 0;
        mExtensionHeader.nonReferenceFrame = !(flags & FLAG_VP8_KEYFRAME);
        mExtensionHeader.partiotionStart = (packetIndex == 0);
        mExtensionHeader.partitionId = packetIndex;
        
        return &mExtensionHeader;
    }
    
    virtual bool isKeyframe(jrtplib::RTPPacket *rtppack) const
    {
        assert(rtppack->GetExtensionLength() == getSize());
        Vp8RTPExtensionHeader *extension = (Vp8RTPExtensionHeader*)rtppack->GetExtensionData();
        return (extension->partiotionStart && !extension->nonReferenceFrame);
    }
    
    virtual bool hasKeyframes() { return true; }
    
    virtual size_t getNumWords() const { return sizeof(Vp8RTPExtensionHeader) / sizeof(uint32_t); }
    virtual size_t getSize() const { return sizeof(Vp8RTPExtensionHeader); }
    virtual uint16_t getId() const { return 0; }
    
private:
    mutable Vp8RTPExtensionHeader mExtensionHeader;
};

#endif