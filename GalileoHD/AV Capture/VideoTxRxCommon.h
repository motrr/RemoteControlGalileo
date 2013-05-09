//
//  Vp8RtpPacket.h
//  GalileoHD
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#ifndef GalileoHD_VideoTxRxCommon_h
#define GalileoHD_VideoTxRxCommon_h

// Capture framerate of the camera
#define CAPTURE_FRAMES_PER_SECOND   20
#define RTP_TIMEBASE 90000 // defined by VP8 RTP spec

// Width and height for video as it exists in transit
#define VIDEO_WIDTH 768
#define VIDEO_HEIGHT 512
#define TARGET_BITRATE_PER_PIXEL 4
#define MAX_KEYFRAME_INTERVAL 30 // 0 for all keyframes

// UDP port used for transmitting audio/video
#define AV_UDP_PORT 1234

// Maximum size of a video frame
#define MAX_FRAME_LENGTH 250000

// RTP packet header struct
/*
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |V=2|P|X|  CC   |M|     PT      |       sequence number         |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                           timestamp                           |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |           synchronization source (SSRC) identifier            |
 +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
 */
typedef struct {
    
    // First octet
    unsigned char  csrc_count      : 4;
    unsigned char  extension       : 1;
    unsigned char  padding         : 1;
    unsigned char  version         : 2;
    
    // Second octet
    unsigned char  payload_type    : 7;
    unsigned char  marker          : 1;
    
    // Remaining bytes
    unsigned short sequence_num    : 16;
    unsigned long timestamp         : 32;    
    unsigned long ssrc              : 32;
    
} RtpPacketHeaderStruct;



// VP8 payload descriptor struct
/*
 0 1 2 3 4 5 6 7
 +-+-+-+-+-+-+-+-+
 |X|R|N|S|PartID | (REQUIRED)
 +-+-+-+-+-+-+-+-+
 */
typedef struct {
    
    // First octet
    unsigned char  extended_control_present     : 1;
    unsigned char  reserved                     : 1;
    unsigned char  non_reference_frame          : 1;
    unsigned char  start_of_partition           : 1;
    unsigned char  partition_id                 : 4;
    
    
} Vp8PayloadDescriptorStruct;

// Packet preamble size, contains the RTP packet headers
#define PACKET_PREAMBLE_LENGTH (sizeof(RtpPacketHeaderStruct)+sizeof(Vp8PayloadDescriptorStruct))

// The first packets are small since they require copying into memory to prepend the header
#define FIRST_PACKET_PAYLOAD_LENGTH 50
#define FIRST_PACKET_TOTAL_LENGTH (PACKET_PREAMBLE_LENGTH+FIRST_PACKET_PAYLOAD_LENGTH)

// Subsequent packets should use the maximum allowed size
#define MAX_PACKET_PAYLOAD_LENGTH 1450
#define MAX_PACKET_TOTAL_LENGTH (PACKET_PREAMBLE_LENGTH+MAX_PACKET_PAYLOAD_LENGTH)


#endif // GalileoHD_VideoTxRxCommon_h
