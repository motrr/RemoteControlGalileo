//
//  VideoPacketiser.h
//  GalileoHD
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PacketSender;

@interface Vp8RtpPacketiser : NSObject
{
    PacketSender* packetSender;
}

- (void) prepareForSendingTo: (NSString*) ipAddress onPort: (unsigned int) port;
- (void) sendFrame: (NSData*) data;

@end
