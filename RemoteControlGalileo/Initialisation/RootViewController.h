//  Created by Chris Harding on 10/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Created and initialised directly from the application delegate. Creates a session manager, which is run through a game lobby to obtain a connection to a peer. The session manager is then used to initialise a Galileo object. View controllers for the lobby and the Galileo object are pushed on and off the navigation stack. Changes in connection state are handled.

#import <UIKit/UIKit.h>
#import "GalileoCommon.h"
#import "GKCommon.h"

@class GKSessionManager;
@class GKLobbyViewController;
@class GKNetController;
@class RemoteControlGalileo;


@interface RootViewController : UIViewController <ConnectionStateResponderDelegate>

@end
