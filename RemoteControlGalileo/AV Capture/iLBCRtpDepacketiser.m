//
//  VideoDepacketiser.m
//  RemoteControlGalileo
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "iLBCRtpDepacketiser.h"
#import "VideoTxRxCommon.h"

@implementation iLBCRtpDepacketiser

- (id) initWithPort: (u_short) inputPort
{
    if (self = [super initWithPort:inputPort payloadDescriptorLength:0]) {
    }
    
    return self;
}

- (void) processEncodedData: (NSData*) data
{
    [self.delegate processEncodedData:data];
}

@end
