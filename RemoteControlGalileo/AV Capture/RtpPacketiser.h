//
//  VideoPacketiser.h
//  RemoteControlGalileo
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PacketSender;

@interface RtpPacketiser : NSObject
{
    PacketSender* packetSender;
    unsigned int payloadHeaderLength; // payloadLength = sizeof(RtpPacketHeaderStruct) + sizeof(CustomPayloadDescriptorStruct) if any
    
    // some variables you may use for custom packed header, todo?
    unsigned int current_start_of_partition;
}

// payloadDescriptorLength = sizeof(CustomPayloadDescriptorStruct) for example, if 0 no descriptor
- (id) initWithPayloadType: (unsigned char) payloadType payloadDescriptorLength: (unsigned int) payloadDescriptorLength;
- (id) initWithPayloadType: (unsigned char) payloadType; // payloadLength = sizeof(RtpPacketHeaderStruct)

- (void) prepareForSendingTo: (NSString*) ipAddress onPort: (unsigned int) port;
- (void) sendFrame: (NSData*) data;
// will free data when done, make sure to use malloc() to allocate data
- (void) sendFrame: (void*) bytes length: (unsigned int) length;

// internal, override this if you want to add some custom data to your payload
// CustomPayloadDescriptorStruct* rtpPacketHeader = (CustomPayloadDescriptorStruct*) buffer;
- (void) insertCustomPacketHeader: (char*) buffer;

@end
