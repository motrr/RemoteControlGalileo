#ifndef RtpPacketiser_H
#define RtpPacketiser_H

#include "VideoTxRxCommon.h"
#include "Buffer.h"

#include <string>

class Socket;
class RtpPacketiser
{
public:
    // payloadDescriptorLength = sizeof(CustomPayloadDescriptorStruct) for example, if 0 no descriptor
    RtpPacketiser(unsigned char payloadType, size_t payloadDescriptorLength = 0);
    virtual ~RtpPacketiser();

    bool configure(const std::string &ipAddress, size_t port);
    void sendFrame(void *buffer, size_t size);
    
protected:
    // internal, override this if you want to add some custom data to your payload
    // CustomPayloadDescriptorStruct* rtpPacketHeader = (CustomPayloadDescriptorStruct*) buffer;
    virtual void insertCustomPacketHeader(char *buffer);
    void insertPacketHeader(char *buffer);
    
    void sendFrameInOnePacket(void *buffer, size_t size);
    void sendFrameInMultiplePackets(void *buffer, size_t size);
    void nextPacketIsLastInFrame();
    void nextPacketIsFirstInFrame();
    void nextPacketIsFirstInPartition();

    //
    Socket *mSocket;
    size_t mPayloadHeaderLength; // payloadLength = sizeof(RtpPacketHeaderStruct) + sizeof(CustomPayloadDescriptorStruct) if any
    
    // Skeleton packet headers to copy in, only a few fields need to be dynamically set
    RtpPacketHeaderStruct mSkeletonRtpPacketHeader;
    
    // Buffer to hold the first packet of each frame only
    char mFirstPacket[MAX_FIRST_PACKET_PAYLOAD_LENGTH];
    
    size_t mCurrentMarker;
    size_t mCurrentSequenceNumber;
    size_t mCurrentTimestamp;
    size_t mCurrentPartitionStart;
};

#endif
