#ifndef Vp8RtpPacketiser_H
#define Vp8RtpPacketiser_H

#include "RtpPacketiser.h"
#include "VideoTxRxCommon.h"

class Vp8RtpPacketiser : public RtpPacketiser
{
public:
    Vp8RtpPacketiser(unsigned char payloadType); // payloadLength = sizeof(RtpPacketHeaderStruct) + sizeof(Vp8PayloadDescriptorStruct)
    ~Vp8RtpPacketiser();

protected:
    virtual void insertCustomPacketHeader(char *buffer);

    //
    Vp8PayloadDescriptorStruct mSkeletonPayloadDescriptor;
};

#endif
