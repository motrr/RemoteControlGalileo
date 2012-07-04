//  Created by Chris Harding on 23/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GalileoCommon.h"

// BSD sockets
#import <arpa/inet.h>
#import <sys/socket.h>
#import <netinet/in.h>

@interface RtpPacketSender : NSObject
{
    // Socket open flag
    BOOL socketHasBeenOpened;
    
    // Sending vars
    char buf[AV_UDP_BUFFER_LEN];
    struct sockaddr_in si_other;
    int videoTxSocket;
}

// Open socket, send frames, then close socket
- (void) openSocketWithIpAddress: (NSString*) ipAddress port: (u_short) port;
- (void) sendFrame: (NSData*) data;
- (void) closeSocket;


@end


