//
//  VideoPacketiser.h
//  GalileoHD
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RtpPacketiser.h"

@interface Vp8RtpPacketiser : RtpPacketiser

- (id) initWithPayloadType: (unsigned char) payloadType; // payloadLength = sizeof(RtpPacketHeaderStruct) + sizeof(Vp8PayloadDescriptorStruct)
- (void) insertCustomPacketHeader: (char*) buffer;

@end
