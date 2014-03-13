#ifndef VideoTxRxCommon_h
#define VideoTxRxCommon_h

#define FORCE_REAR_CAMERA YES
//#define FORCE_LOW_QUALITY
#define HAS_AUDIO_STREAMING

// Capture framerate of the camera
#define CAPTURE_FRAMES_PER_SECOND   10
#define RTP_TIMEBASE 90000 // defined by VP8 RTP spec

// Resolution of video stream
#define VIDEO_WIDTH_LOW 192
#define VIDEO_HEIGHT_LOW 128
#define TARGET_BITRATE_PER_PIXEL_LOW 4
#define VIDEO_WIDTH 480
#define VIDEO_HEIGHT 360
#define TARGET_BITRATE_PER_PIXEL 6
#define MAX_KEYFRAME_INTERVAL 10 // 0 for all keyframes

#define USE_SINGLE_PASS_PREPROCESS

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
typedef struct
{   
    // First octet
    unsigned char csrcCount     : 4;
    unsigned char extension     : 1;
    unsigned char padding       : 1;
    unsigned char version       : 2;
    
    // Second octet
    unsigned char payloadType   : 7;
    unsigned char marker        : 1;
    
    // Remaining bytes
    unsigned short sequenceNum  : 16;
    unsigned long timestamp     : 32;
    unsigned long ssrc          : 32;
    
} RtpPacketHeaderStruct;

// VP8 payload descriptor struct
/*
 0 1 2 3 4 5 6 7
 +-+-+-+-+-+-+-+-+
 |X|R|N|S|PartID | (REQUIRED)
 +-+-+-+-+-+-+-+-+
 */
typedef struct
{
    // First octet
    unsigned char extendedControlPresent    : 1;
    unsigned char reserved                  : 1;
    unsigned char nonReferenceFrame         : 1;
    unsigned char partiotionStart           : 1;
    unsigned char partitionId               : 4;
    
} Vp8PayloadDescriptorStruct;


// The first packets are small since they require copying into memory to prepend the header
//#define FIRST_PACKET_PAYLOAD_LENGTH 50

// sizeof(header) + 2 bytes for possible descriptor
#define MAX_PACKET_PAYLOAD_HEADER_LENGTH (sizeof(RtpPacketHeaderStruct) + 2)

// Subsequent packets should use the maximum allowed size
#define MAX_PACKET_PAYLOAD_LENGTH 1450U
#define MAX_PACKET_TOTAL_LENGTH (MAX_PACKET_PAYLOAD_HEADER_LENGTH + MAX_PACKET_PAYLOAD_LENGTH)

// Using max packet length for first packet to descease number of sends and prevent
// packet loss on wifi networks (we will have redundant memcpy, but less losses)
#define FIRST_PACKET_PAYLOAD_LENGTH MAX_PACKET_PAYLOAD_LENGTH
#define MAX_FIRST_PACKET_PAYLOAD_LENGTH (MAX_PACKET_PAYLOAD_HEADER_LENGTH + FIRST_PACKET_PAYLOAD_LENGTH)

#endif
