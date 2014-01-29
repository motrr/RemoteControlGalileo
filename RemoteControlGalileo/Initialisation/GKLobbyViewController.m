//  Created by Chris Harding on 02/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <GameKit/GameKit.h> 
#import <QuartzCore/QuartzCore.h>
#import "GKLobbyViewController.h"

#define TITLE_BAR_HEIGHT 44
#define TOOLBAR_HEIGHT 0 // 44
#define IPAD_SIZE_FRACTION  0.6

@implementation GKLobbyViewController

@synthesize connectionStateResponder;


#pragma mark View controller methods

- (id)initWithSessionManager:(GKSessionManager *) aManager
    connectionStateResponder: (id <ConnectionStateResponderDelegate>) aConnectionStateResponder;
{
    self = [super init];
    if (self) {
        manager = aManager;
        [self setConnectionStateResponder: aConnectionStateResponder];
    }
    return self;
}

- (void)viewDidLoad 
{
    // Create the view for notifying the user of status, and possibly presenting a list of peers
    self.view = [[UIView alloc] init];
    CGRect viewFrame = [UIScreen mainScreen].applicationFrame;
    CGPoint viewCenter = CGPointMake(viewFrame.size.width / 2.0,
                                 viewFrame.size.height / 2.0);
    
    // Get frame depending on format
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        viewFrame = CGRectMake(0,0, IPAD_SIZE_FRACTION*viewFrame.size.width,
                                    IPAD_SIZE_FRACTION*viewFrame.size.height);
        [self.view.layer setMasksToBounds:YES];
        [self.view.layer setCornerRadius:5.0f];
        self.view.frame = viewFrame;
        self.view.center = viewCenter;
    }
    else {
        self.view.frame = viewFrame;
    }
    
    // Create title bar
    UINavigationBar* navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0,
                                                                                      viewFrame.size.width,
                                                                                      TITLE_BAR_HEIGHT )];
    UINavigationItem* title = [[UINavigationItem alloc] initWithTitle:@"Galileo Peer List"];
    [navigationBar setItems: [NSArray arrayWithObject:title]];
    [self.view addSubview:navigationBar];
    
    
    // Create table with list of peers
    tableView = [[UITableView alloc] initWithFrame:CGRectMake(
                                        0,
                                        TITLE_BAR_HEIGHT,
                                        viewFrame.size.width,
                                        viewFrame.size.height - TITLE_BAR_HEIGHT - TOOLBAR_HEIGHT )];
    [tableView setDataSource:self];
    [tableView setDelegate:self];
    [self.view addSubview: tableView];
    
    
    // Create toolbar with status text
    /*
    UIToolbar* toolbar = [[UIToolbar alloc] initWithFrame: CGRectMake(0,
                                                                     viewFrame.size.height - TOOLBAR_HEIGHT,
                                                                     viewFrame.size.width,
                                                                     TOOLBAR_HEIGHT)];
    [self.view addSubview: toolbar];
     */
    
    
    // Set self as lobby delegate
    [manager setLobbyDelegate:self];
    [manager setupSession];
    [self peerListDidChange:nil];
}



// On becoming visible
- (void) viewDidAppear:(BOOL)animated
{
    [manager setupSession];
    [self peerListDidChange:nil];
}


#pragma mark -
#pragma mark Opening Method

// Called when user selects a peer from the list or accepts a call invitation.
- (void) openGameScreenWithPeerID:(NSString *)peerID
{
    // When peer is selected (manally or otherwise) we handle using the connection state responder
    [self.connectionStateResponder peerSelected];

}


#pragma mark -
#pragma mark Table Data Source Methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [peerList count];
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
	static NSString *TopLevelCellIdentifier = @"TopLevelCellIdentifier";
	
	UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:TopLevelCellIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:TopLevelCellIdentifier];
	}

	NSUInteger row = [indexPath row];
	cell.textLabel.text = [manager displayNameForPeer:[peerList objectAtIndex:row]];
	
    return cell;
}

#pragma mark Table View Delegate Methods

// The user selected a peer from the list to connect to.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[manager connect:[peerList objectAtIndex:[indexPath row]]]; 
	[self openGameScreenWithPeerID:[peerList objectAtIndex:[indexPath row]]]; 
}

#pragma mark -
#pragma mark GameSessionLobbyDelegate Methods

- (void) peerListDidChange:(GKSessionManager *)session;
{
    peerList = [[NSMutableArray alloc] init];
    NSString* peerID;
    for (peerID in session.peerList) {
        if (![[manager displayNameForPeer:peerID] isEqualToString:[[UIDevice currentDevice] name]]) {
            [peerList addObject:peerID];
        }
    }

    NSLog(@"List of peers changed - %d peers found", [peerList count]);
    [tableView reloadData]; 
    
}

// Invitation dialog due to peer attempting to connect.
- (void) didReceiveInvitation:(GKSessionManager *)session fromPeer:(NSString *)participantID;
{
    // Auto accept any invites
    if ([manager didAcceptInvitation])
        [self openGameScreenWithPeerID:manager.currentConfPeerID];
    
    /*
	NSString *str = [NSString stringWithFormat:@"Incoming Invite from %@", participantID];
    if (alertView.visible) {
        [alertView dismissWithClickedButtonIndex:0 animated:NO];
    }
	alertView = [[UIAlertView alloc] 
				 initWithTitle:str
				 message:@"Do you wish to accept?" 
				 delegate:self 
				 cancelButtonTitle:@"Decline" 
				 otherButtonTitles:nil];
	[alertView addButtonWithTitle:@"Accept"]; 
	[alertView show];
     */
    
}

// Display an alert sheet indicating a failure to connect to the peer.
- (void) invitationDidFail:(GKSessionManager *)session fromPeer:(NSString *)participantID
{
    NSString *str;
    if (alertView.visible) {
        // Peer cancelled invitation before it could be accepted/rejected
        // Close the invitation dialog before opening an error dialog
        [alertView dismissWithClickedButtonIndex:0 animated:NO];
        str = [NSString stringWithFormat:@"%@ cancelled call", participantID]; 
    } else {
        // Peer rejected invitation or exited app.
        str = [NSString stringWithFormat:@"%@ declined your call", participantID]; 
    }
    
    alertView = [[UIAlertView alloc] initWithTitle:str message:nil delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
}

#pragma mark -
#pragma mark UIAlertViewDelegate Methods

// User has reacted to the dialog box and chosen accept or reject.
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == 1) {
        // User accepted.  Open the game screen and accept the connection.
        if ([manager didAcceptInvitation])
            [self openGameScreenWithPeerID:manager.currentConfPeerID]; 
	} else {
        [manager didDeclineInvitation];
	}
}

@end
