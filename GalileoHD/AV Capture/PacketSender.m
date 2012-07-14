//  Created by Chris Harding on 23/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "PacketSender.h"


@implementation PacketSender

- (id) init
{
    if (self = [super init]) {
        socketHasBeenOpened = NO;
    }
    return self;
} 

- (void) dealloc
{
    NSLog(@"VideoTransmitter exiting");
    
    // Close socket
    [self closeSocket];
    
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
    unsigned int x = MAX_PACKET_TOTAL_LENGTH;
    unsigned int y = sizeof(x);
    NSLog( @"Attempting to set socket send buffer to %u bytes", x);
    setsockopt( videoTxSocket, SOL_SOCKET, SO_SNDBUF, &x,y );
    getsockopt( videoTxSocket, SOL_SOCKET, SO_SNDBUF, &x,&y );
    NSLog( @"Socket send buffer is %u bytes", x);
    
    // Set flag
    socketHasBeenOpened = YES;
    
}

// Send a single packet
- (void) sendPacket:(NSData *)data
{    
    // Send fragment over socket
    if (sendto(videoTxSocket,
               [data bytes],
               [data length], 0, (struct sockaddr*) &si_other, sizeof(si_other)) == -1) {
        NSLog(@"Erorr when sending packet.");
    }
    
}

// Close the socket when done
- (void) closeSocket
{
    close( videoTxSocket );
    socketHasBeenOpened = NO;
}

@end
