//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Responds to Galileo control signals by sending commands through the GalileoControl library.

#import <Foundation/Foundation.h>
#import "GalileoCommon.h"

@interface DockConnectorController : NSObject <GalileoControlResponderDelegate>

@end
