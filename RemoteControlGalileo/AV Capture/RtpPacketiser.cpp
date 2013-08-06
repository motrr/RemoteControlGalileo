#include "RtpPacketiser.h"
#include "Socket.h"


RtpPacketiser::RtpPacketiser(unsigned char payloadType, size_t payloadDescriptorLength):
mSocket(0)
{
    // NOTE - the excerpts printed here are abbreviated, see the (draft) specifications for the further detail.
    
    /*
    version (V): 2 bits
    This field identifies the version of RTP.  The version defined by
    this specification is two (2).  (The value 1 is used by the first
    draft version of RTP and the value 0 is used by the protocol
    initially implemented in the "vat" audio tool.)
        
    padding (P): 1 bit
    If the padding bit is set, the packet contains one or more
    additional padding octets at the end which are not part of the
    payload.  The last octet of the padding contains a count of how
    many padding octets should be ignored, including itself.  Padding
    may be needed by some encryption algorithms with fixed block sizes
    or for carrying several RTP packets in a lower-layer protocol data
    unit.
        
    extension (X): 1 bit
    If the extension bit is set, the fixed header MUST be followed by
    exactly one header extension, with a format defined in Section
    5.3.1.
    
    CSRC count (CC): 4 bits
    The CSRC count contains the number of CSRC identifiers that follow
    the fixed header.

    Marker bit (M):  Set for the very last packet of each encoded frame
    in line with the normal use of the M bit in video formats.  This
    enables a decoder to finish decoding the picture, where it
    otherwise may need to wait for the next packet to explicitly know
    that the frame is complete.
    
    payload type (PT): 7 bits
    This field identifies the format of the RTP payload and determines
    its interpretation by the application.  A profile MAY specify a
    default static mapping of payload type codes to payload formats.
    Additional payload type codes MAY be defined dynamically through
    non-RTP means (see Section 3).  A set of default mappings for
    audio and video is specified in the companion RFC 3551 [1].  An
    RTP source MAY change the payload type during a session, but this
    field SHOULD NOT be used for multiplexing separate media streams
    (see Section 5.2).
        
    A receiver MUST ignore packets with payload types that it does not
    understand.
    
    Sequence number:  The sequence numbers are monotonically increasing
    and set as packets are sent.
    
    Timestamp:  The RTP timestamp indicates the time when the frame was
    sampled at a clock rate of 90 kHz.
    
    SSRC: 32 bits
    The SSRC field identifies the synchronization source.  This
    identifier SHOULD be chosen randomly, with the intent that no two
    synchronization sources within the same RTP session will have the
    same SSRC identifier.  An example algorithm for generating a
    random identifier is presented in Appendix A.6.  Although the
    probability of multiple sources choosing the same identifier is
    low, all RTP implementations must be prepared to detect and
    resolve collisions.  Section 8 describes the probability of
    collision along with a mechanism for resolving collisions and
    detecting RTP-level forwarding loops based on the uniqueness of
    the SSRC identifier.  If a source changes its source transport
    address, it must also choose a new SSRC identifier to avoid being
    interpreted as a looped source (see Section 8.2).
    */
    mSkeletonRtpPacketHeader.version = 0x2;
    mSkeletonRtpPacketHeader.padding = 0;
    mSkeletonRtpPacketHeader.extension = 0;
    mSkeletonRtpPacketHeader.csrcCount = 0;
    //
    mSkeletonRtpPacketHeader.marker = 0; // Set on send
    mSkeletonRtpPacketHeader.payloadType = payloadType; // Should be dynamically set on initiation, static for now
    mSkeletonRtpPacketHeader.sequenceNum = htons(0); // Set on send
    mSkeletonRtpPacketHeader.timestamp = htonl(0); // Set on send
    mSkeletonRtpPacketHeader.ssrc = htonl(0xBABEB00B); // Should be dynamically set on initiation, static for now
    
    // These needs to be set correctly before sending
    mCurrentMarker = 0;
    mCurrentPartitionStart = 0;
    
    // Initial sequence number should be random, for now we use 0 for debugging
    mCurrentSequenceNumber = 0;
    
    // This should be incremented correctly for each new frame
    mCurrentTimestamp = time(NULL);
    
    // Check that the first packet payload lenght is big enough to prepend a packet header for the next packet
    mPayloadHeaderLength = sizeof(RtpPacketHeaderStruct) + payloadDescriptorLength;
    assert(mPayloadHeaderLength < MAX_PACKET_PAYLOAD_HEADER_LENGTH);
    assert(mPayloadHeaderLength < FIRST_PACKET_PAYLOAD_LENGTH);
}

RtpPacketiser::~RtpPacketiser()
{
    delete mSocket;
}

bool RtpPacketiser::configure(const std::string &ipAddress, size_t port)
{
    assert(!mSocket);
    
    // Create packet sender
    mSocket = new Socket();
    return mSocket->openSocket(ipAddress, port, MAX_PACKET_TOTAL_LENGTH);
}

void RtpPacketiser::sendFrame(void *buffer, size_t size, bool isKey)
{
    if(size <= FIRST_PACKET_PAYLOAD_LENGTH)
    {
        // Very small frames can be sent in one packet
        sendFrameInOnePacket(buffer, size, isKey);
    }
    else
    {
        // Normally we split into at least two packet, the first being very small as it MUST require copying to prepend the packet header
        sendFrameInMultiplePackets(buffer, size, isKey);
    }
}

void RtpPacketiser::sendFrameInOnePacket(void *buffer, size_t size, bool isKey)
{
    // Just reuse the first packet buffer
    char *packet = mFirstPacket;
    
    // Copy the packet so we can prepend the header
    char *mPacketPayload = packet + mPayloadHeaderLength;
    memcpy(mPacketPayload, buffer, size);
    
    // This is the first and last packet in a frame so set state accordingly
    nextPacketIsFirstInFrame();
    nextPacketIsLastInFrame();
    
    // Insert a packet header and send
    insertPacketHeader(packet, isKey);
    mSocket->sendPacket(packet, size + mPayloadHeaderLength);
    //printf("Sent packet %u\n", ntohs(((RtpPacketHeaderStruct*)packet)->sequence_num));
}

void RtpPacketiser::sendFrameInMultiplePackets(void *buffer, size_t size, bool isKey)
{
    // The first packet requires copying to a temperary buffer so we can prepend the packet header
    char *firstPacketPayload = mFirstPacket + mPayloadHeaderLength;
    memcpy(firstPacketPayload, buffer, FIRST_PACKET_PAYLOAD_LENGTH);
    unsigned int mFirstPacketPayloadLength = FIRST_PACKET_PAYLOAD_LENGTH + mPayloadHeaderLength;
    
    // This is the first packet in a frame so set state accordingly
    nextPacketIsFirstInFrame();
    
    // Insert a packet header and send
    insertPacketHeader(mFirstPacket, isKey);
    mSocket->sendPacket(mFirstPacket, mFirstPacketPayloadLength);
    //printf("Sent packet %u\n", ntohs(((RtpPacketHeaderStruct*)mFirstPacket)->sequence_num));
    
    // For subsequent packets we write headers into the data as we go, so no copying needs to be done
    unsigned int bytesLeft = size - FIRST_PACKET_PAYLOAD_LENGTH;
    unsigned int bytesSent = 0;
    char *nextPacketPayload = (char*)buffer + FIRST_PACKET_PAYLOAD_LENGTH;
    char *nextPacketHeader = nextPacketPayload - mPayloadHeaderLength;
    unsigned int nextPacketPayloadLength;
    unsigned int nextPacketTotalLength;
    //
    while(bytesLeft > 0)
    {
        // Calculate size of next packet
        nextPacketPayloadLength = std::min(bytesLeft, MAX_PACKET_PAYLOAD_LENGTH);
        nextPacketTotalLength = nextPacketPayloadLength + mPayloadHeaderLength;
        
        // Check if this is the last packet
        if(bytesLeft <= MAX_PACKET_PAYLOAD_LENGTH)
        {
            nextPacketIsLastInFrame();
        }
        
        // Insert frame and send the packet
        insertPacketHeader(nextPacketHeader, isKey);
        mSocket->sendPacket(nextPacketHeader, nextPacketTotalLength);
        //printf("Sent packet %u\n", ntohs(((RtpPacketHeaderStruct*)nextPacketHeader)->sequence_num));
        
        // Advance
        bytesLeft -= nextPacketPayloadLength;
        bytesSent += nextPacketPayloadLength;
        nextPacketHeader += nextPacketPayloadLength;
        
        // Wait a while if we are sending a huge packet, this reduces packet loss (especially for the critical first frame)
        if(bytesSent > 1000)
        {
            bytesSent = 0;
            usleep(20000); // 20 ms, TODO - Investigate different intervals
        }
    }
}

void RtpPacketiser::nextPacketIsLastInFrame()
{
    // Set end (marker) bit, it will be reset on use
    mCurrentMarker = 1;
    
}
void RtpPacketiser::nextPacketIsFirstInFrame()
{
    // Increase timestamp
    mCurrentTimestamp += (1.0 / CAPTURE_FRAMES_PER_SECOND) * RTP_TIMEBASE;
    
    // Next frame will also be new partition
    nextPacketIsFirstInPartition();
}

void RtpPacketiser::nextPacketIsFirstInPartition()
{
    // Set start bit, it will be reset on use
    mCurrentPartitionStart = 1;
}

void RtpPacketiser::insertPacketHeader(char *buffer, bool isKey)
{
    // Alias to the packet headers in the buffer
    RtpPacketHeaderStruct* rtpPacketHeader = (RtpPacketHeaderStruct*)buffer;
    
    // Copy in the skeleton headers
    memcpy(rtpPacketHeader, &mSkeletonRtpPacketHeader, sizeof(mSkeletonRtpPacketHeader));
    
    // Fill out dynamic fields
    rtpPacketHeader->marker = mCurrentMarker;
    //
    rtpPacketHeader->sequenceNum = htons(mCurrentSequenceNumber);
    mCurrentSequenceNumber++; // always increments on every packet
    //
    rtpPacketHeader->timestamp = htonl(mCurrentTimestamp);
    
    insertCustomPacketHeader(buffer + sizeof(RtpPacketHeaderStruct), isKey);
    
    // We always reset the start and end frame (marker) indicators, they must be set explicitly
    mCurrentPartitionStart = 0;
    mCurrentMarker = 0;
}

void RtpPacketiser::insertCustomPacketHeader(char *buffer, bool isKey)
{
    // do nothing
}
