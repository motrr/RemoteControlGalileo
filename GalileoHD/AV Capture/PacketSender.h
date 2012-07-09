//  Created by Chris Harding on 23/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoTxRxCommon.h"

// BSD sockets
#import <arpa/inet.h>
#import <sys/socket.h>
#import <netinet/in.h>

@interface PacketSender : NSObject
{
    // Socket open flag
    BOOL socketHasBeenOpened;
    
    // Sending vars
    char buf[MAX_PACKET_TOTAL_LENGTH];
    struct sockaddr_in si_other;
    int videoTxSocket;
}

// Open socket, send frames, then close socket
- (void) openSocketWithIpAddress: (NSString*) ipAddress port: (u_short) port;
- (void) sendPacket: (NSData*) data;
- (void) closeSocket;


@end


