//
//  VideoPacketiser.m
//  GalileoHD
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "Vp8RtpPacketiser.h"
#import "VideoTxRxCommon.h"

@interface Vp8RtpPacketiser ()
{
    Vp8PayloadDescriptorStruct skeletonPayloadDescriptor;
}

@end

@implementation Vp8RtpPacketiser

- (id) initWithPayloadType: (unsigned char) payloadType
{
    if (self = [super initWithPayloadType:payloadType payloadDescriptorLength:sizeof(Vp8PayloadDescriptorStruct)]) {
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
    }
    
    return self;
}

- (void) insertCustomPacketHeader: (char*) buffer;
{
    // Alias to the packet headers in the buffer
    Vp8PayloadDescriptorStruct* vp8PayloadDescriptor = (Vp8PayloadDescriptorStruct*) buffer;
    
    // Copy in the skeleton headers
    memcpy(vp8PayloadDescriptor, &skeletonPayloadDescriptor, sizeof(skeletonPayloadDescriptor));
    
    //
    vp8PayloadDescriptor->non_reference_frame = 0; // TODO - actually set this for keyframes
    vp8PayloadDescriptor->start_of_partition = current_start_of_partition;
}


@end
