//
//  VideoDepacketiser.h
//  GalileoHD
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RtpDepacketiser : NSObject
{
    u_short port;
    unsigned int rxSocket;
    unsigned int payloadHeaderLength;
}

// should we care about payload type?
- (id) initWithPort: (u_short) port payloadDescriptorLength: (unsigned int) payloadDescriptorLength;

- (void) openSocket;
- (void) startListening;
- (void) closeSocket;

// override this for subclasses
- (void) processEncodedData: (NSData*) data;
- (void) insertPacketIntoFrame: (char*) payload payloadDescriptor:(char*) payload_descriptor 
                 payloadLength: (unsigned int) payload_length markerSet: (Boolean) marker;

@end
