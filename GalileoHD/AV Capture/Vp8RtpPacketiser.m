//
//  VideoPacketiser.m
//  GalileoHD
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "Vp8RtpPacketiser.h"
#import "VideoTxRxCommon.h"
#import "PacketSender.h"

@interface Vp8RtpPacketiser ()
{
    // Skeleton packet headers to copy in, only a few fields need to be dynamically set
    RtpPacketHeaderStruct skeletonRtpPacketHeader;
    Vp8PayloadDescriptorStruct skeletonPayloadDescriptor;
    
    // Buffer to hold the first packet of each frame only
    char first_packet[FIRST_PACKET_TOTAL_LENGTH];
    
    unsigned int current_marker;
    unsigned int current_start_of_partition;
    unsigned int current_sequence_number;
    unsigned int current_timestamp;
    
}

@end

@implementation Vp8RtpPacketiser

- (id) init
{
    if (self = [super init]) {
        
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
        skeletonRtpPacketHeader.version = 0x2 ;
        skeletonRtpPacketHeader.padding = 0 ;
        skeletonRtpPacketHeader.extension = 0 ;
        skeletonRtpPacketHeader.csrc_count = 0 ;
        //
        skeletonRtpPacketHeader.marker = 0 ; // Set on send
        skeletonRtpPacketHeader.payload_type = 96 ; // Should be dynamically set on initiation, static for now
        skeletonRtpPacketHeader.sequence_num = htons(0) ; // Set on send
        skeletonRtpPacketHeader.timestamp = htonl(0) ; // Set on send
        skeletonRtpPacketHeader.ssrc = htonl(0xBABEB00B) ; // Should be dynamically set on initiation, static for now
        
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
        skeletonPayloadDescriptor.extended_control_present = 0;
        skeletonPayloadDescriptor.reserved = 0;
        skeletonPayloadDescriptor.non_reference_frame = 0; // Set on send
        skeletonPayloadDescriptor.start_of_partition = 0; // Set on send
        skeletonPayloadDescriptor.partition_id = 0;
        
        // These needs to be set correctly before sending
        current_marker = 0;
        current_start_of_partition = 0;
        
        // Initial sequence number should be random, for now we use 0 for debugging
        current_sequence_number = 0;
      
        // This should be incremented correctly for each new frame
        current_timestamp = [NSDate timeIntervalSinceReferenceDate];
        
        // Check that the first packet payload lenght is big enough to prepend a packet header for the next packet
        assert(PACKET_PREAMBLE_LENGTH < FIRST_PACKET_PAYLOAD_LENGTH);
    }
	
    return self;
}

- (void) dealloc
{
    NSLog(@"VideoPacketiser exiting");
}

- (void) prepareForSendingTo:(NSString *)ipAddress onPort:(unsigned int)port
{
    // Create packet sender
    packetSender = [[PacketSender alloc] init];
    [packetSender openSocketWithIpAddress:ipAddress port:port];
}

- (void) sendFrame:(NSData*)data
{

    // Very small frames can be sent in one packet
    if ([data length] <= FIRST_PACKET_PAYLOAD_LENGTH) {
        [self sendFrameInOnePacket:data];
    }
    // Normally we split into at least two packet, the first being very small as it MUST require copying to prepend the packet header
    else {
        [self sendFrameInMultiplePackets:data];
    }
}


- (void) sendFrameInOnePacket: (NSData*) data
{
    NSLog(@"One frame packet");
    
    // Just reuse the first packet buffer
    char * packet = first_packet;
    
    // Copy the packet so we can prepend the header
    char* packet_payload = packet + PACKET_PREAMBLE_LENGTH;
    memcpy(packet_payload, [data bytes], [data length]);
    
    // This is the first and last packet in a frame so set state accordingly
    [self nextPacketIsFirstInFrame];
    [self nextPacketIsLastInFrame];
    
    // Insert a packet header and send
    [self insertPacketHeader:packet];
    NSData* testData = [NSData dataWithBytesNoCopy:packet length:[data length]+PACKET_PREAMBLE_LENGTH freeWhenDone:NO];
    [packetSender sendPacket:testData];
    
}
- (void) sendFrameInMultiplePackets: (NSData*) data
{
    
    // The first packet requires copying to a temperary buffer so we can prepend the packet header
    char* first_packet_payload = first_packet + PACKET_PREAMBLE_LENGTH;
    memcpy(first_packet_payload, [data bytes], FIRST_PACKET_PAYLOAD_LENGTH);
    
    // This is the first packet in a frame so set state accordingly
    [self nextPacketIsFirstInFrame];
    
    // Insert a packet header and send
    [self insertPacketHeader:first_packet];
    [packetSender sendPacket:[NSData dataWithBytesNoCopy:first_packet length:FIRST_PACKET_TOTAL_LENGTH freeWhenDone:NO]];
    
    // For subsequent packets we write headers into the data as we go, so no copying needs to be done
    unsigned int bytes_left = [data length] - FIRST_PACKET_PAYLOAD_LENGTH;
    char * next_packet_payload = (char*)[data bytes] + FIRST_PACKET_PAYLOAD_LENGTH;
    char * next_packet_header = next_packet_payload - PACKET_PREAMBLE_LENGTH;
    unsigned int next_packet_length;
    //
    while (bytes_left > 0) {
        
        // Calculate size of next packet
        next_packet_length = MIN(bytes_left, MAX_PACKET_PAYLOAD_LENGTH);
        
        // Check if this is the last packet
        if (bytes_left <= MAX_PACKET_PAYLOAD_LENGTH) {
            [self nextPacketIsLastInFrame];
        }
        
        // Insert frame and send the packet
        [self insertPacketHeader:next_packet_header];
        [packetSender sendPacket:[NSData dataWithBytesNoCopy:next_packet_header length:next_packet_length freeWhenDone:NO]];
        
        // Advance
        bytes_left -= next_packet_length;
        next_packet_header += next_packet_length;
        
    }
}

- (void) nextPacketIsLastInFrame
{
    // Set end (marker) bit, it will be reset on use
    current_marker = 1;
    
}
- (void) nextPacketIsFirstInFrame
{
    // Increase timestamp
    current_timestamp += (1.0 / CAPTURE_FRAMES_PER_SECOND) * RTP_TIMEBASE;
    
    // Next frame will also be new partition
    [self nextPacketIsFirstInPartition];
}
- (void) nextPacketIsFirstInPartition
{
    // Set start bit, it will be reset on use
    current_start_of_partition = 1;
}


- (void) insertPacketHeader: (char*) buffer
{
    // Alias to the packet headers in the buffer
    RtpPacketHeaderStruct* rtpPacketHeader = (RtpPacketHeaderStruct*) buffer;
    Vp8PayloadDescriptorStruct* vp8PayloadDescriptor = (Vp8PayloadDescriptorStruct*) buffer+sizeof(RtpPacketHeaderStruct);
    
    // Copy in the skeleton headers
    memcpy(rtpPacketHeader, &skeletonRtpPacketHeader, sizeof(skeletonRtpPacketHeader));
    memcpy(vp8PayloadDescriptor, &skeletonPayloadDescriptor, sizeof(skeletonPayloadDescriptor));
    
    // Fill out dynamic fields
    rtpPacketHeader->marker = current_marker;
    //
    rtpPacketHeader->sequence_num = htons(current_sequence_number);
    current_sequence_number++; // always increments on every packet
    //
    rtpPacketHeader->timestamp = htonl(current_timestamp);
    //
    vp8PayloadDescriptor->non_reference_frame = 0; // TODO - actually set this for keyframes
    vp8PayloadDescriptor->start_of_partition = current_start_of_partition;
    
    // We always reset the start and end frame (marker) indicators, they must be set explicitly
    current_start_of_partition = 0;
    current_marker = 0;
    

    
}


@end
