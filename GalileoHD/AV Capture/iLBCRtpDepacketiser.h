//
//  VideoDepacketiser.h
//  GalileoHD
//
//  Created by Chris Harding on 03/07/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RtpDepacketiser.h"
#import "GalileoCommon.h"

@interface iLBCRtpDepacketiser : RtpDepacketiser

@property (nonatomic, weak) id<AudioDepacketiserDelegate> delegate;

- (id) initWithPort: (u_short) port;
- (void) processEncodedData: (NSData*) data;

@end
