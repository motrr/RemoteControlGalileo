//
//  VideoDepacketiser.m
//  GalileoHD
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoDepacketiser.h"
#import "VideoTxRxCommon.h"

#import "VideoDecoder.h"
#import "VideoView.h"

#import <sys/socket.h>
#import <netinet/in.h>

@interface VideoDepacketiser ()
{
    // BSD socket recieves frames
    u_short port;
    unsigned int videoRxSocket;
    
}

@end

@implementation VideoDepacketiser

- (id) init
{
    if (self = [super init]) {
        port = AV_UDP_PORT;
    }
    return self;
    
}

- (void) dealloc
{
    NSLog(@"VideoDepacketiser exiting");
    [self closeSocket];
}

#pragma mark -
#pragma mark Video reception over UDP

// Start listening for tranmission on a UDP port
- (void) openSocket
{
    NSLog(@"Listening for video on port %u", port);
    
    // Declare variables
    struct sockaddr_in si_me;
    
    // Create a server socket
    if ((videoRxSocket=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP))==-1)
        NSLog(@"Failed to create video Rx socket.");
    
    // Create the address
    memset((char *) &si_me, 0, sizeof(si_me));
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(port);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    
    // Bind address to socket
    if ( bind(videoRxSocket, (struct sockaddr *) &si_me, sizeof(si_me)) == -1) {
        NSLog(@"Failed to bind video Rx socket to address.");
    }
    
}

- (void) startListeningForVideo
{
    struct sockaddr_in si_other;
    unsigned int slen=sizeof(si_other);
    
    RtpPacketHeaderStruct packet_header;
    Vp8PayloadDescriptorStruct payload_descriptor;
    
    char a_frame[MAX_FRAME_LENGTH];
    char b_frame[MAX_FRAME_LENGTH];
    char* current_frame = a_frame;
    char scratch_space[MAX_PACKET_PAYLOAD_LENGTH];
    unsigned int current_timestamp = 0;
    unsigned short incoming_timestamp;
    int amount_read;
    unsigned int bytes_in_frame_so_far = 0;
    
    // Begin listening for data (JPEG video frames)
    for (;;) {
        
        // Otherwise, recieve and display frame
        @autoreleasepool {
            
            // First read the packet headers
            amount_read = recvfrom(videoRxSocket, &packet_header, sizeof(RtpPacketHeaderStruct), 0,(struct sockaddr *) &si_other, &slen);
            if (amount_read < 0) [self errorReadingFromSocket];
            amount_read = recvfrom(videoRxSocket, &payload_descriptor, sizeof(Vp8PayloadDescriptorStruct), 0,(struct sockaddr *) &si_other, &slen);
            if (amount_read < 0) [self errorReadingFromSocket];
            
            incoming_timestamp = ntohl(packet_header.timestamp);
            
            NSLog(@"Read packet with timestamp %u", incoming_timestamp);
            
            
            // If packet is old, then discard the payload and move on
            if (true) { // (incoming_sequence_num < current_sequence_num) {
                
                NSLog(@"Discarding old packet");
                amount_read = recvfrom(videoRxSocket, scratch_space, MAX_PACKET_PAYLOAD_LENGTH, 0,(struct sockaddr *) &si_other, &slen);
                if (amount_read < 0) [self errorReadingFromSocket];
                
            }
            else {
                
                // If packet is from the current frame:
                if (incoming_timestamp == current_timestamp) {
                    
                    NSLog(@"Reading packet into frame");
                    
                    // Read the payload into the frame at the correct position
                    amount_read = recvfrom(videoRxSocket, current_frame+bytes_in_frame_so_far, MAX_PACKET_PAYLOAD_LENGTH,
                                           0,(struct sockaddr *) &si_other, &slen);
                    if (amount_read < 0) [self errorReadingFromSocket];
                    
                    // Ensure the next fragment gets written in the correct position
                    bytes_in_frame_so_far += amount_read;
                    
                }

                // If this packet is from a new frame OR its the last packet in the current frame:
                if ((incoming_timestamp > current_timestamp) || (packet_header.marker == 1)) {
                    
                    // Don't try display partial frames
                    if (incoming_timestamp == current_timestamp) {
                        
                        // Display the current frame
                        [self displayFrame:[NSData dataWithBytesNoCopy:current_frame length:bytes_in_frame_so_far freeWhenDone:NO]];
                    }
                    
                    // Advance to the next frame
                    NSLog(@"Advancing to next frame");
                    current_frame = (current_frame == a_frame) ? (b_frame) : (a_frame) ;
                    current_timestamp = incoming_timestamp;
                    bytes_in_frame_so_far = 0;
                }
                
                // If this packet is from a new frame:
                if (incoming_timestamp > current_timestamp) {
                    
                    NSLog(@"Reading NEWER packet into NEW frame");
                    
                    // Read the payload into the frame at the correct position
                    amount_read = recvfrom(videoRxSocket, current_frame+bytes_in_frame_so_far, MAX_PACKET_PAYLOAD_LENGTH,
                                           0,(struct sockaddr *) &si_other, &slen);
                    if (amount_read < 0) [self errorReadingFromSocket];
                    
                    // Ensure the next fragment gets written in the correct position
                    bytes_in_frame_so_far += amount_read;
                    
                }
            }
            
        }
        
    }
    
    
}

- (void) errorReadingFromSocket
{
    NSLog(@"Bad return value from server socket recvrom()." );
    [NSThread exit];
}

- (void) recievePacket:(NSData *)data
{
    // Read the packet header
    
    
    // Read the packet payload into the correct place
    
    // If we see the RTP mark, this is the last packet of the frame so we should display it
    
}

- (void) displayFrame: (NSData*) data
{
    NSLog(@"Displaying frame");
    
    // Decode data into a pixel buffer
    CVPixelBufferRef pixelBuffer = [videoDecoder decodeFrameData:data];
    
    // Render the pixel buffer using OpenGL
    [self.viewForDisplayingFrames performSelectorOnMainThread:@selector(renderPixelBuffer:) withObject:(__bridge id)(pixelBuffer) waitUntilDone:YES];
}


- (void) closeSocket
{
    close(videoRxSocket);
}

@end
