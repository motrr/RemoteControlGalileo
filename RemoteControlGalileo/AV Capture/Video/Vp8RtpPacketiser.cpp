#include "Vp8RtpPacketiser.h"

Vp8RtpPacketiser::Vp8RtpPacketiser(unsigned char payloadType):
    RtpPacketiser(payloadType, sizeof(Vp8PayloadDescriptorStruct))
{
    /*
    X: Extended control bits present.  When set to one, the extension
    octet MUST be provided immediately after the mandatory first
    octet.  If the bit is zero, all optional fields MUST be omitted.
    
    R: Bit reserved for future use.  MUST be set to zero and MUST be
    ignored by the receiver.
         
    N: Non-reference frame.  When set to one, the frame can be discarded
    without affecting any other future or past frames.  If the
    reference status of the frame is unknown, this bit SHOULD be set
    to zero to avoid discarding frames needed for reference.
    
    S: Start of VP8 partition.  SHOULD be set to 1 when the first payload
    octet of the RTP packet is the beginning of a new VP8 partition,
    and MUST NOT be 1 otherwise.  The S bit MUST be set to 1 for the
    first packet of each encoded frame.
    
    PartID:  Partition index.  Denotes which VP8 partition the first
    payload octet of the packet belongs to.  The first VP8 partition
    (containing modes and motion vectors) MUST be labeled with PartID
    = 0.  PartID SHOULD be incremented for each subsequent partition,
    but MAY be kept at 0 for all packets.  PartID MUST NOT be larger
    than 8.  If more than one packet in an encoded frame contains the
    same PartID, the S bit MUST NOT be set for any other packet than
    the first packet with that PartID.
    */
    mSkeletonPayloadDescriptor.extendedControlPresent = 0;
    mSkeletonPayloadDescriptor.reserved = 0;
    mSkeletonPayloadDescriptor.nonReferenceFrame = 0; // Set on send
    mSkeletonPayloadDescriptor.partiotionStart = 0; // Set on send
    mSkeletonPayloadDescriptor.partitionId = 0;
}

Vp8RtpPacketiser::~Vp8RtpPacketiser()
{
    
}

void Vp8RtpPacketiser::insertCustomPacketHeader(char *buffer, bool isKey)
{
    // Alias to the packet headers in the buffer
    Vp8PayloadDescriptorStruct *vp8PayloadDescriptor = (Vp8PayloadDescriptorStruct*)buffer;
    
    // Copy in the skeleton headers
    memcpy(vp8PayloadDescriptor, &mSkeletonPayloadDescriptor, sizeof(mSkeletonPayloadDescriptor));
    
    //
    vp8PayloadDescriptor->nonReferenceFrame = isKey; // TODO - actually set this for keyframes
    vp8PayloadDescriptor->partiotionStart = mCurrentPartitionStart;
}
