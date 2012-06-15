//  Created by Chris Harding on 22/12/2011.
//  Copyright (c) 2011 Swift Navigation. All rights reserved.
//
//  Implements the NetworkControllerDelegate using a GKSession. Also delegates handling of incoming packets.

#import <UIKit/UIKit.h>
#import "GKSessionManager.h"
#import "GalileoCommon.h"

@interface GKNetController : NSObject <SessionManagerGameDelegate, NetworkControllerDelegate>
{
    __weak GKSessionManager *manager;
    
    // Vars for ping/pong
    UInt16 pingCounter;
    NSMutableDictionary *pingTable;
    
}

- (id) initWithManager: (GKSessionManager *) aManager;

// Connection start/end code is delegated
@property (nonatomic, weak) id <ConnectionStateResponderDelegate> connectionStateResponder;

@end
