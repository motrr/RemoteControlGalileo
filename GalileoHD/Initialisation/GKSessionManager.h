//  Created by Chris Harding on 02/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h> 
#import "GKCommon.h"

@interface GKSessionManager : NSObject <GKSessionDelegate> {
	NSString *sessionID;
	GKSession *myGKSession;
	NSString *currentConfPeerID;
	NSMutableArray *peerList;
    ConnectionState sessionState;
}

@property (nonatomic, readonly) NSString *currentConfPeerID;
@property (nonatomic, readonly) NSMutableArray *peerList;
@property (nonatomic, weak) id <SessionManagerLobbyDelegate> lobbyDelegate;
@property (nonatomic, weak) id <SessionManagerGameDelegate> gameDelegate;

- (void) setupSession;
- (void) connect:(NSString *)peerID;
- (BOOL) didAcceptInvitation;
- (void) didDeclineInvitation;
-(void) sendPacket:(NSData*)data ofType:(PacketType)type reliable:(Boolean) reliable;
- (void) disconnectCurrentCall;
- (NSString *) displayNameForPeer:(NSString *)peerID;

@end

// Class extension for private methods.
@interface GKSessionManager ()

- (BOOL) comparePeerID:(NSString*)peerID;
- (BOOL) isReadyToStart;
- (void) destroySession;
- (void) willTerminate:(NSNotification *)notification;
- (void) willResume:(NSNotification *)notification;

@end

