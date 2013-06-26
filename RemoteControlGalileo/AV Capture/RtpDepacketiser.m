//
//  VideoDepacketiser.m
//  RemoteControlGalileo
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "RtpDepacketiser.h"
#import "VideoTxRxCommon.h"

#import <sys/socket.h>
#import <netinet/in.h>

#define PACKET_BUFFER_SIZE 10
#define FRAME_BUFFER_SIZE 20

@interface RtpDepacketiser ()
{
    // Dispatch queue for decoding
    dispatch_queue_t decodingQueue;
    
    char* current_frame;
    
    // We keep a buffer of frames, so decoding and depacketising can take place concurrently
    char* frame_buffer[FRAME_BUFFER_SIZE];
    unsigned int current_frame_index;
    
    // We keep a buffer of packets to deal with out of order packets
    char* packet_buffer[PACKET_BUFFER_SIZE];
    unsigned int next_packet_index;
    
    unsigned int incoming_timestamp;
    unsigned int next_sequence_num;
    unsigned int incoming_sequence_num;
    
    unsigned int bytes_in_frame_so_far;
    
    Boolean skipThisFrame;
}

@end

@implementation RtpDepacketiser

- (id) initWithPort: (u_short) inputPort payloadDescriptorLength: (unsigned int) payloadDescriptorLength
{
    if (self = [super init]) {
        payloadHeaderLength = sizeof(RtpPacketHeaderStruct) + payloadDescriptorLength;
        port = inputPort;
        
        // Create queue for decoding frames
        char buffer[64];
        sprintf(buffer, "Decoding queue %d", port);
        decodingQueue = dispatch_queue_create(buffer, NULL);
    }
    
    return self;
}

- (void) dealloc
{
    NSLog(@"RtpDepacketiser exiting");
    [self closeSocket];
    
    for (int i=0; i<FRAME_BUFFER_SIZE; i++) {
        free( frame_buffer[i] );
    }
    
    for (int i=0; i<PACKET_BUFFER_SIZE; i++) {
        free( packet_buffer[i] );
    }
}

#pragma mark -
#pragma mark Reception over UDP

// Start listening for tranmission on a UDP port
- (void) openSocket
{
    NSLog(@"Listening on port %u", port);
    
    // Declare variables
    struct sockaddr_in si_me;
    
    // Create a server socket
    if ((rxSocket=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP))==-1)
        NSLog(@"Failed to create video Rx socket.");
    
    // Create the address
    memset((char *) &si_me, 0, sizeof(si_me));
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(port);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    
    // Bind address to socket
    if ( bind(rxSocket, (struct sockaddr *) &si_me, sizeof(si_me)) == -1) {
        NSLog(@"Failed to bind video Rx socket to address.");
    }
}

- (void) closeSocket
{
    close(rxSocket);
}

- (void) startListening
{
    int amount_read;
    
    RtpPacketHeaderStruct *packet_header;
    char *payload_descriptor;
    
    char* payload;
    unsigned int payload_length;
    
    // Create a fixed size buffer for reading packets into
    for (int i=0; i<PACKET_BUFFER_SIZE; i++) {
        packet_buffer[i] = malloc(MAX_PACKET_TOTAL_LENGTH);
    }
    next_packet_index = 0;
    next_sequence_num = 0;
    bytes_in_frame_so_far = 0;
    
    // Create fixed size buffer fro reading frames into
    for (int i=0; i<FRAME_BUFFER_SIZE; i++) {
        frame_buffer[i] = malloc(MAX_FRAME_LENGTH);
    }
    current_frame_index = 0;
    current_frame = frame_buffer[current_frame_index];
    
    // We skip displaying any frame that has one or more packets missing
    skipThisFrame = NO;
    
    // Begin listening for data
    for (;;) {
        
        // Otherwise, recieve and display frame
        @autoreleasepool {
            // First read the packet
            amount_read = recv(rxSocket, packet_buffer[next_packet_index], MAX_PACKET_TOTAL_LENGTH, 0);
            if (amount_read < 0) [self errorReadingFromSocket];
            
            // Alias to packet header, payload descriptor and payload
            packet_header = (RtpPacketHeaderStruct*) packet_buffer[next_packet_index];
            payload_descriptor = (char*) (packet_buffer[next_packet_index] + sizeof(packet_header));
            payload = packet_buffer[next_packet_index] + payloadHeaderLength;
            payload_length = amount_read - payloadHeaderLength;
            incoming_sequence_num = ntohs(packet_header->sequence_num);
            incoming_timestamp = ntohl(packet_header->timestamp);
            
            //NSLog(@"Recieved packet %u, payload length %u", incoming_sequence_num, payload_length);
            
            // If we are not skipping this frame, examine the packet
            if (!skipThisFrame) {
                // Completely ignore old packets
                if (incoming_sequence_num < next_sequence_num) {
                    
                    NSLog(@"Warning saw an old packet");
                }
                // Store future packets for later (if we have buffer space)
                else if (incoming_sequence_num > next_sequence_num) {
                    
                    NSLog(@"Packet is from the future, buffering for later use");
                    next_packet_index++;
                    
                    if (next_packet_index == PACKET_BUFFER_SIZE) {
                        NSLog(@"Packet buffer overflow occured, will have to skip this frame");
                        skipThisFrame = YES;
                        next_packet_index = 0;
                    }
                }
                // Otherwise, insert this packet (and also any others from the buffer) into the frame
                else {
                    
                    // Insert the this packet
                    [self insertPacketIntoFrame:payload payloadDescriptor:payload_descriptor 
                                  payloadLength:payload_length markerSet:packet_header->marker];
                    
                    // Try insert any packets from the buffer
                    for (int i=0; i<next_packet_index; i++) {
                        
                        // Alias to packet header, payload descriptor and payload
                        packet_header = (RtpPacketHeaderStruct*) packet_buffer[i];
                        payload_descriptor = (char*) (packet_buffer[i] + sizeof(packet_header));
                        payload = packet_buffer[i] + payloadHeaderLength;
                        payload_length = amount_read - payloadHeaderLength;
                        incoming_sequence_num = ntohs(packet_header->sequence_num);
                        incoming_timestamp = ntohl(packet_header->timestamp);
                        
                        if (incoming_sequence_num == next_sequence_num) {
                            
                            // Insert packet
                            [self insertPacketIntoFrame:payload payloadDescriptor:payload_descriptor 
                                          payloadLength:payload_length markerSet:packet_header->marker];
                            
                            // Remove packet from the buffer
                            if (next_packet_index > 1) {
                                packet_buffer[i] = packet_buffer[next_packet_index-1];
                                next_packet_index--;
                            }
                            else next_packet_index = 0;
                            
                            // Reset iterator so we loop through again
                            i = 0;
                        }
                    }
                }
            }
            // If we are skipping this frame, we don't do anything till a marker packet
            else if (packet_header->marker) {
                
                NSLog(@"Resetting after skip");
                // Reset state so the next frame can be decoded
                bytes_in_frame_so_far = 0;
                skipThisFrame = NO;
                next_sequence_num = incoming_sequence_num+1;
            }
            
        }
        
    }
    
}

- (void) insertPacketIntoFrame: (char*) payload payloadDescriptor:(char*) payload_descriptor 
                 payloadLength: (unsigned int) payload_length markerSet: (Boolean) marker
{
    
    // Insert packet into frame
    memcpy( current_frame+bytes_in_frame_so_far, payload, payload_length );
    bytes_in_frame_so_far += payload_length;
    next_sequence_num++;
    
    // If mark is set, this is the last packet of the frame
    if (marker) {
        
        //NSLog(@"Displaying frame");
            
        // Wait till queue is empty
        dispatch_sync(decodingQueue, ^{});
        
        // Queue up a frame to be decoded
        NSData* frameData = [NSData dataWithBytesNoCopy:current_frame length:bytes_in_frame_so_far freeWhenDone:NO];
        dispatch_async(decodingQueue, ^{
            
            [self processEncodedData:frameData];
            
        });
        
        // Swap frames so we don't write into the old one whilst decoding, and reset counter
        current_frame_index = (current_frame_index+1) % FRAME_BUFFER_SIZE;
        current_frame = frame_buffer[current_frame_index];
        bytes_in_frame_so_far = 0;
        
    }
}

- (void) errorReadingFromSocket
{
    NSLog(@"Bad return value from server socket recvrom()." );
    [NSThread exit];
}

- (void) processEncodedData: (NSData*) data 
{
}

@end
