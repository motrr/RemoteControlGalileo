//  Created by Chris Harding on 02/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GKSessionManager.h"
#import "GalileoCommon.h"

@class Galileo;

@interface GKLobbyViewController : UITableViewController 
<UITableViewDelegate, UITableViewDataSource, SessionManagerLobbyDelegate, UIAlertViewDelegate>
{
    
	NSMutableArray	*peerList;
    UIAlertView *alertView;
    UITableView* tableView;
    
    __weak GKSessionManager *manager;

}

- (id)initWithSessionManager:(GKSessionManager *) aManager
    connectionStateResponder: (id <ConnectionStateResponderDelegate>) connectionStateResponder;

// Connection start/end code is delegated
@property (nonatomic, weak) id <ConnectionStateResponderDelegate> connectionStateResponder;


@end
