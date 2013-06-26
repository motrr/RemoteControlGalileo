//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#ifndef RemoteControlGalileo_VideoTxRxCommon_h
#define RemoteControlGalileo_VideoTxRxCommon_h

#define FORCE_REAR_CAMERA YES

// Capture framerate of the camera
#define CAPTURE_FRAMES_PER_SECOND   10
#define RTP_TIMEBASE 90000 // defined by VP8 RTP spec

// Resolution of video stream
#define VIDEO_WIDTH 480 // 192
#define VIDEO_HEIGHT 360 // 128
#define TARGET_BITRATE_PER_PIXEL 5
#define MAX_KEYFRAME_INTERVAL 10 // 0 for all keyframes

// UDP port used for transmitting audio/video
#define AUDIO_UDP_PORT 1234
#define VIDEO_UDP_PORT 1235

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


// The first packets are small since they require copying into memory to prepend the header
#define FIRST_PACKET_PAYLOAD_LENGTH 50

// sizeof(header) + 2 bytes for possible descriptor
#define MAX_PACKET_PAYLOAD_HEADER_LENGTH (sizeof(RtpPacketHeaderStruct) + 2)
#define MAX_FIRST_PACKET_PAYLOAD_LENGTH (FIRST_PACKET_PAYLOAD_LENGTH + MAX_PACKET_PAYLOAD_HEADER_LENGTH)

// Subsequent packets should use the maximum allowed size
#define MAX_PACKET_PAYLOAD_LENGTH 1450
#define MAX_PACKET_TOTAL_LENGTH (MAX_PACKET_PAYLOAD_HEADER_LENGTH + MAX_PACKET_PAYLOAD_LENGTH)


#endif // RemoteControlGalileo_VideoTxRxCommon_h
