#ifndef RtpSessionEx_H
#define RtpSessionEx_H

#include "rtpsession.h"
#include "rtpudpv4transmitter.h"
#include "rtpipv4address.h"
#include "rtpsessionparams.h"
#include "rtperrors.h"
#include "rtppacket.h"
#include "rtpsourcedata.h"

#include "VideoTxRxCommon.h"
#include "Function.h"

#include <iostream>
#include <vector>

// PACKET_SEQUENCE_DIFF - minimal difference between seq. numbers from last inserted packet 
// and minimal seq. number from packet list when we will discart packets to the next keyframe
// invalid/old packets.
#define PACKET_SEQUENCE_DIFF 5
#define PACKET_BUFFER_SIZE 25
#define FRAME_BUFFER_SIZE 20
//#define SKIP_TO_KEYFRAME

class RTPExtensionHelper
{
public:
    virtual ~RTPExtensionHelper() {}
    
    virtual jrtplib::RTPExtensionHeader *getHeader(int packetIndex, unsigned int flags) const { return 0; }
    virtual size_t getNumWords() const { return 0; }
    virtual size_t getSize() const { return 0; }
    virtual uint16_t getId() const { return 0; }
    virtual bool isKeyframe(jrtplib::RTPPacket *rtppack) const { return false; }
    virtual bool hasKeyframes() { return false; }
};

class RTPSessionEx : public jrtplib::RTPSession
{
public:
    typedef Function<void(void *data, size_t length)> DepacketizerCallback;
    
    //
    ~RTPSessionEx();

    static RTPSessionEx *CreateInstance(unsigned char payloadType, int timestampIncrement, 
                                               const std::string &destAddress, int portBase);
    
    void SetDepacketizerCallback(DepacketizerCallback callback);
    void SetRTPExtensionHelper(RTPExtensionHelper *helper); // will take over helper
    int SendMultiPacket(void *data, size_t size, unsigned int flags);
    
protected:
    RTPSessionEx();

    virtual void OnPollThreadStep();
    void ProcessRTPPacket(jrtplib::RTPSourceData *srcdat, jrtplib::RTPPacket *rtppack);
    void InsertPacketIntoFrame(jrtplib::RTPPacket *rtppack);

    RTPExtensionHelper *mRTPExtensionHelper;
    unsigned char mPayloadType;
    int mTimestampIncrement;
    int mMaxDataSize;

    // depacketizer
    char *mCurrentFrame;
    
    // We keep a buffer of frames, so decoding and depacketising can take place concurrently
    char *mFrameBuffer[FRAME_BUFFER_SIZE];
    unsigned int mCurrentFrameIndex;
    unsigned int mByteInFrameSoFar;
    
    // We keep a buffer of packets to deal with out of order packets
    std::vector<jrtplib::RTPPacket*> mPackets;
    int mNextSequenceNum;

    // We skip displaying any frame that has one or more packets missing
    int mNotInsertedCounter;
    int mLastInsertedSequenceNum;
    
    //
    DepacketizerCallback mDepacketizerCallback;
};

#endif