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
    
    // Dispatch queue for decoding
    dispatch_queue_t decodingQueue;
    
    char a_frame[MAX_FRAME_LENGTH];
    char b_frame[MAX_FRAME_LENGTH];
    
}

@end

@implementation VideoDepacketiser

- (id) init
{
    if (self = [super init]) {
        port = AV_UDP_PORT;
        videoDecoder = [[VideoDecoder alloc] init];
        
        // Create queue for decoding frames
        decodingQueue = dispatch_queue_create("Decoding queue", NULL);
        
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
    RtpPacketHeaderStruct *packet_header;
    Vp8PayloadDescriptorStruct *payload_descriptor;
    char* payload;
    
    char* current_frame = a_frame;
    char incoming_packet[MAX_PACKET_TOTAL_LENGTH];
    
    unsigned int current_timestamp = 0;
    unsigned int incoming_timestamp;
    unsigned int next_sequence_num = 0;
    unsigned int incoming_sequence_num;
    
    int amount_read;
    unsigned int payload_length;
    unsigned int bytes_in_frame_so_far = 0;
    
    // We skip displaying any frame which skips over a sequence number
    Boolean skipThisFrame = NO;
    
    // Begin listening for data (JPEG video frames)
    for (;;) {
        
        // Otherwise, recieve and display frame
        @autoreleasepool {
            
            // First read the packet
            amount_read = recv(videoRxSocket, incoming_packet, MAX_PACKET_TOTAL_LENGTH, 0);
            if (amount_read < 0) [self errorReadingFromSocket];
            
            // Alias to packet header, payload descriptor and payload
            packet_header = (RtpPacketHeaderStruct*) incoming_packet;
            payload_descriptor = (Vp8PayloadDescriptorStruct*) (incoming_packet + sizeof(packet_header));
            payload = incoming_packet + PACKET_PREAMBLE_LENGTH;
            payload_length = amount_read - PACKET_PREAMBLE_LENGTH;
            
            incoming_sequence_num = ntohs(packet_header->sequence_num);
            incoming_timestamp = ntohl(packet_header->timestamp);
            //NSLog(@"Read packet with payload length %u, timestamp %u, seq %u", payload_length, incoming_timestamp, incoming_sequence_num);
            
            // Completely ignore old packets
            if (incoming_sequence_num < next_sequence_num) {
                
                NSLog(@"Warning saw an old packet");

            }
            else {
                
                // Skip displaying any frame in which a sequence number skip occurs
                if (incoming_sequence_num != next_sequence_num) {
                    NSLog(@"This frame will be skipped");
                    skipThisFrame = YES;
                }
                
                // Insert packet into frame
                if (!skipThisFrame) {
                    memcpy(current_frame+bytes_in_frame_so_far, payload, payload_length);
                    bytes_in_frame_so_far += payload_length;
                }
                
                // If mark is set, this is the last packet of the frame
                if (packet_header->marker) {
                    
                    // Display the frame
                    if (!skipThisFrame) {

                        // Wait till queue is empty
                        dispatch_sync(decodingQueue, ^{});
                        
                        // Queue up a frame to be decoded
                        NSData* frameData = [NSData dataWithBytesNoCopy:current_frame length:bytes_in_frame_so_far freeWhenDone:NO];
                        dispatch_async(decodingQueue, ^{
                            [self displayFrame:frameData];
                        });
                    }
                    
                    // Advance to the next frame
                    //NSLog(@"Advancing to next frame");
                    current_frame = [self nextFrame:current_frame];
                    bytes_in_frame_so_far = 0;
                    //
                    next_sequence_num = incoming_sequence_num+1;
                    skipThisFrame = NO;
                    
                } else next_sequence_num++;
                
            }
            
        }
        
    }
    
    
}

- (char*) nextFrame: (char*) current_frame
{
    char* next_frame;
    
    if      (current_frame == a_frame) next_frame = b_frame;
    else if (current_frame == b_frame) next_frame = a_frame;
    
    return next_frame;
}

- (void) errorReadingFromSocket
{
    NSLog(@"Bad return value from server socket recvrom()." );
    [NSThread exit];
}


- (void) displayFrame: (NSData*) data
{
    //NSLog(@"Displaying frame");
    
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
