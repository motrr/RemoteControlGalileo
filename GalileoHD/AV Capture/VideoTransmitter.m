//  Created by Chris Harding on 23/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoTransmitter.h"
#import "JPEGFragmentation.h"

@implementation VideoTransmitter

- (id) init
{
    if (self = [super init]) {
        frame_sequence_number = 0;
        fragment = calloc( AV_UDP_BUFFER_LEN, sizeof(char) );
        jpeg_start = calloc(JPEG_HEADER_LENGTH, sizeof(char) );
        socketHasBeenOpened = NO;
    }
    return self;
} 

- (void) dealloc
{
    NSLog(@"VideoTransmitter exiting");
    
    // Close socket
    [self closeSocket];
    
    free(fragment);
    free(jpeg_start);
}


// Connect to a video reciever given an IP and port
- (void) openSocketWithIpAddress: (NSString*) ipAddress port: (u_short) port
{
    
    NSLog(@"Opening UDP socket with destination IP %@ on port %u", ipAddress, port);
    
    // Create socket
    if ((videoTxSocket=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP))==-1)
        NSLog(@"Failed to create socket");
    
    // Create address
    memset((char *) &si_other, 0, sizeof(si_other));
    si_other.sin_family = AF_INET;
    si_other.sin_port = htons(port);
    
    // Process IP address string to network address
    if (inet_aton(ipAddress.UTF8String, &si_other.sin_addr)==0) {
        NSLog(@"Error: inet_aton() failed.");
    }
    
    // Get or set the send buffer size
    unsigned int x = 9216; //AV_UDP_BUFFER_LEN;
    unsigned int y = sizeof(x);
    NSLog( @"Attempting to set socket send buffer to %u bytes", x);
    setsockopt( videoTxSocket, SOL_SOCKET, SO_SNDBUF, &x,y );
    getsockopt( videoTxSocket, SOL_SOCKET, SO_SNDBUF, &x,&y );
    NSLog( @"Socket send buffer is %u bytes", x);
    
    // Set flag
    socketHasBeenOpened = YES;
    
}

// Send a single video frame
- (void) sendFrame: (NSData*) data
{
    //NSData *testData = [NSData dataWithBytes:"startstarthell1hell2hell3hell4hell5hell6hell789" length:47];
    
    frame_sequence_number++;
    
    // Prepend a fragment header to the JPEG data stream
    JPEGFragmentHeaderStruct *fragmentHeader;
    memcpy(fragment+sizeof(JPEGFragmentHeaderStruct), [data bytes], [data length]);
    memcpy(jpeg_start, [data bytes], JPEG_HEADER_LENGTH);
    unsigned int current_fragment_length;
    unsigned int bytes_left = [data length] - sizeof(JPEGFragmentHeaderStruct);
    unsigned int current_offset = 0;
    
    // Send out frame in fragments
    unsigned int i=0;
    while (bytes_left > 0) {
        
        current_fragment_length = MIN(bytes_left+sizeof(JPEGFragmentHeaderStruct)+JPEG_HEADER_LENGTH, MAX_FRAGMENT_LENGTH);
        
        // Fill out the fragment header with offset and length
        fragmentHeader = (JPEGFragmentHeaderStruct*) (fragment+current_offset);
        fragmentHeader->frame_number = frame_sequence_number;
        fragmentHeader->fragment_offset = current_offset + sizeof(JPEGFragmentHeaderStruct) + JPEG_HEADER_LENGTH;
        fragmentHeader->fragment_length = current_fragment_length - (sizeof(JPEGFragmentHeaderStruct) + JPEG_HEADER_LENGTH);
        fragmentHeader->total_length = [data length];
        fragmentHeader->magic_number = 0xB00B;
        
        // Copy start of JPEG byte stream, hope that it contains the header
        if (current_offset != 0) {
            memcpy((fragment+current_offset)+sizeof(JPEGFragmentHeaderStruct), jpeg_start, JPEG_HEADER_LENGTH);
        }
        
        // Send fragment over socket
        if (sendto(videoTxSocket, 
                   (fragment+current_offset), 
                   current_fragment_length, 0, (struct sockaddr*) &si_other, sizeof(si_other)) == -1) {
            NSLog(@"Erorr when sending packet."); 
        }
        
        //NSLog(@"Sending fragment %u of frame %u", i, frame_sequence_number);
        /*
        printf("\n");
        for (int j = sizeof(JPEGFragmentHeaderStruct); j<current_fragment_length; j++) {
            printf( "%c", (fragment+current_offset)[j] );
        }
        printf("\n");
        */
        
        bytes_left -= current_fragment_length - (sizeof(JPEGFragmentHeaderStruct) + JPEG_HEADER_LENGTH);
        current_offset += current_fragment_length - (sizeof(JPEGFragmentHeaderStruct) + JPEG_HEADER_LENGTH);
        i++;
    }
    
}

// Close the socket when done
- (void) closeSocket
{
    close( videoTxSocket );
    socketHasBeenOpened = NO;
}

@end
