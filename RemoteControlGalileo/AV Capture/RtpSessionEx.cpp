#include "RtpSessionEx.h"
#include "rtcpapppacket.h"

RTPSessionEx *RTPSessionEx::CreateInstance(unsigned char payloadType, int timestampIncrement,
                                           const std::string &destAddress, int portBase)
{
    // Prepare RTP library
    RTPSessionEx *rtpSession = new RTPSessionEx();
    rtpSession->SetDefaultPayloadType(payloadType);
    rtpSession->SetDefaultMark(false);
    rtpSession->SetDefaultTimestampIncrement(timestampIncrement);

    // store for internal use
    rtpSession->mPayloadType = payloadType;
    rtpSession->mTimestampIncrement = timestampIncrement;

    //
    jrtplib::RTPSessionParams sessionParams;
    sessionParams.SetOwnTimestampUnit(1.0 / timestampIncrement);
    sessionParams.SetUsePollThread(true);
    sessionParams.SetMaximumPacketSize(MAX_PACKET_PAYLOAD_LENGTH);

    jrtplib::RTPUDPv4TransmissionParams transParams;
    transParams.SetPortbase(portBase);

    int status = rtpSession->Create(sessionParams, &transParams);
    if(status)
    {
        printf("ERROR: %s\n", jrtplib::RTPGetErrorString(status).c_str());
        assert(false);
    }

    uint32_t destip = inet_addr(destAddress.c_str());

    // The inet_addr function returns a value in network byte order, but
    // we need the IP address in host byte order, so we use a call to
    // ntohl
    destip = ntohl(destip);

    jrtplib::RTPIPv4Address addr(destip, portBase);
    status = rtpSession->AddDestination(addr);
    if(status)
    {
        printf("ERROR: %s\n", jrtplib::RTPGetErrorString(status).c_str());
        assert(false);
    }

    return rtpSession;
}

RTPSessionEx::RTPSessionEx():
mRTPExtensionHelper(0),
mPayloadType(0),
mTimestampIncrement(0),
mMaxDataSize(0)
{
    SetRTPExtensionHelper(new RTPExtensionHelper());

    // depacketizer
    mPackets.reserve(PACKET_BUFFER_SIZE);

    mNextSequenceNum = -1;
    mByteInFrameSoFar = 0;

    // Create fixed size buffer fro reading frames into
    for(int i = 0; i < FRAME_BUFFER_SIZE; i++)
        mFrameBuffer[i] = (char *)malloc(MAX_FRAME_LENGTH);

    mCurrentFrameIndex = 0;
    mCurrentFrame = mFrameBuffer[mCurrentFrameIndex];

    //
    mNotInsertedCounter = 0;
    mLastInsertedSequenceNum = 0;
}

RTPSessionEx::~RTPSessionEx()
{
    delete mRTPExtensionHelper;

    for(int i = 0; i < FRAME_BUFFER_SIZE; i++)
        free(mFrameBuffer[i]);
}

void RTPSessionEx::SetRTPExtensionHelper(RTPExtensionHelper *helper)
{
    delete mRTPExtensionHelper;
    mRTPExtensionHelper = helper;
    mMaxDataSize = MAX_PACKET_PAYLOAD_LENGTH - mRTPExtensionHelper->getSize() - sizeof(jrtplib::RTPHeader);
    mMaxDataSize -= sizeof(uint32_t) * ((size_t)1); // numcsrcs
}

void RTPSessionEx::OnAPPPacket(jrtplib::RTCPAPPPacket *apppacket, const jrtplib::RTPTime &receivetime, const jrtplib::RTPAddress *senderaddress)
{
    printf("RTCP packet received\n");
    if (!mRTCPHandleCallback.empty())
        mRTCPHandleCallback(apppacket);
}

void RTPSessionEx::OnPollThreadStep()
{
    BeginDataAccess();

    // check incoming packets
    if (GotoFirstSourceWithData())
    {
        do
        {
            jrtplib::RTPPacket *pack;
            jrtplib::RTPSourceData *srcdat = GetCurrentSourceInfo();

            while((pack = GetNextPacket()) != NULL)
            {
                ProcessRTPPacket(srcdat, pack);
            }
        }
        while(GotoNextSourceWithData());
    }

    EndDataAccess();
}

void RTPSessionEx::ProcessRTPPacket(jrtplib::RTPSourceData *srcdat, jrtplib::RTPPacket *rtppack)
{
    // 1. You can inspect the packet and the source's info here
    //std::cout << "Got packet " << rtppack->GetExtendedSequenceNumber() << " from SSRC " << srcdat->GetSSRC() << std::endl;

    // 2. Insert packets to frame
    bool insertedPacket = false;

    if(mNextSequenceNum == -1) mNextSequenceNum = rtppack->GetSequenceNumber();
    mPackets.push_back(rtppack);

    std::vector<jrtplib::RTPPacket*>::iterator it = mPackets.begin();
    std::vector<jrtplib::RTPPacket*>::iterator iend = mPackets.end();
    for(; it != iend; )
    {
        jrtplib::RTPPacket *packet = *it;
        if(packet->GetSequenceNumber() == mNextSequenceNum)
        {
            InsertPacketIntoFrame(packet);

            // erase inserted packet
            DeletePacket(packet);
            mPackets.erase(it);

            // Save last inserted index
            insertedPacket = true;
            mLastInsertedSequenceNum = mNextSequenceNum;
            mNextSequenceNum++;

            // Iterate one more time to check other packets
            // to be inserted after current
            it = mPackets.begin();
            iend = mPackets.end();
        }
        else
        {
            ++it;
        }
    }

    // 3. If no packets was inserted
    if(!insertedPacket)
    {
        int currSequenceNum = rtppack->GetSequenceNumber();

        // Increase not inserted packets counter
        mNotInsertedCounter++;

        // Check unsended packets counter for overflow
        if(mNotInsertedCounter > PACKET_BUFFER_SIZE || currSequenceNum - mLastInsertedSequenceNum >= PACKET_SEQUENCE_DIFF)
        {
            printf("Searching #%u:\n", mNextSequenceNum);

#       ifdef SKIP_TO_KEYFRAME
            if(mRTPExtensionHelper->isKeyframe(rtppack))
            {
                mNotInsertedCounter = 0;
                mByteInFrameSoFar   = 0;
                mLastInsertedSequenceNum = mNextSequenceNum;
                mNextSequenceNum++;

                printf("Skipping to the next key frame packet #%u\n", mLastInsertedSequenceNum);
                InsertPacketIntoFrame(rtppack);
            }
            else if(!mRTPExtensionHelper->hasKeyframes())
#       endif
            {
                if(rtppack->HasMarker())
                {
                    mNotInsertedCounter = 0;
                    mByteInFrameSoFar   = 0;
                    mNextSequenceNum = currSequenceNum + 1;

                    printf("Skipping to the next packet #%u\n", mNextSequenceNum);
                }
            }
        }
    }
    else
    {
        // If some frame was inserted reset counter
        mNotInsertedCounter = 0;
    }

    // 4. Cleanup packets we dont need
    for(it = mPackets.begin(), iend = mPackets.end(); it != iend; )
    {
        jrtplib::RTPPacket *packet = *it;
        if(packet->GetSequenceNumber() < mNextSequenceNum)
        {
            // erase inserted packet
            DeletePacket(packet);
            it = mPackets.erase(it);
            iend = mPackets.end();
        }
        else
        {
            ++it;
        }
    }
}

void RTPSessionEx::InsertPacketIntoFrame(jrtplib::RTPPacket *rtppack)
{
    // Insert packet into frame
    memcpy(mCurrentFrame + mByteInFrameSoFar, rtppack->GetPayloadData(), rtppack->GetPayloadLength());
    mByteInFrameSoFar += rtppack->GetPayloadLength();

    // If mark is set, this is the last packet of the frame
    if(rtppack->HasMarker())
    {
        if(!mDepacketizerCallback.empty()) mDepacketizerCallback(mCurrentFrame, mByteInFrameSoFar);

        // Swap frames so we don't write into the old one whilst decoding, and reset counter
        mCurrentFrameIndex = (mCurrentFrameIndex + 1) % FRAME_BUFFER_SIZE;
        mCurrentFrame = mFrameBuffer[mCurrentFrameIndex];
        mByteInFrameSoFar = 0;
    }
}

int RTPSessionEx::SendMultiPacket(void *data, size_t size, unsigned int flags)
{
    if(size <= mMaxDataSize)
    {
        int status = SendPacketEx(data, size, mPayloadType, true, mTimestampIncrement,
                                  mRTPExtensionHelper->getId(), mRTPExtensionHelper->getHeader(0, flags), mRTPExtensionHelper->getNumWords());
        if(status)
        {
            printf("ERROR: %s\n", jrtplib::RTPGetErrorString(status).c_str());
            return status;
        }
    }
    else
    {
        int packetCount = (size - 1) / mMaxDataSize + 1;
        int incrementPerPacket = mTimestampIncrement / packetCount;
        int totalIncrement = mTimestampIncrement;

        char *bufferStart = (char*)data;
        char *bufferEnd = bufferStart + size;

        int index = 0;
        while(bufferStart < bufferEnd)
        {
            size_t newSize = bufferEnd - bufferStart;
            if(newSize > mMaxDataSize) newSize = mMaxDataSize;

            if(totalIncrement < incrementPerPacket)
                incrementPerPacket = totalIncrement;

            bool marker = (index + 1 == packetCount);
            int status = SendPacketEx(bufferStart, newSize, mPayloadType, marker, incrementPerPacket,
                                      mRTPExtensionHelper->getId(), mRTPExtensionHelper->getHeader(index, flags), mRTPExtensionHelper->getNumWords());
            if(status)
            {
                printf("ERROR: %s\n", jrtplib::RTPGetErrorString(status).c_str());
                return status;
            }

            totalIncrement -= incrementPerPacket;
            bufferStart += newSize;
            index++;

            // Wait a while if we are sending a huge packet, this reduces packet loss (especially for the critical first frame)
            // some smart sleeping
            usleep(newSize > 1000 ? 20000 : 10000);
        }
    }
    
    return 0;
}
