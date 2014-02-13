//  Created by Chris Harding on 02/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import "GKSessionManager.h"

#define SESSION_ID @"galileowifi"

@implementation GKSessionManager

@synthesize currentConfPeerID;
@synthesize peerList;
@synthesize lobbyDelegate;
@synthesize gameDelegate;

#pragma mark -
#pragma mark NSObject Methods

- (id)init 
{
	if (self = [super init]) {
        
        // Peers need to have the same sessionID set on their GKSession to see each other.
		sessionID = SESSION_ID; 
		peerList = [[NSMutableArray alloc] init];
        
        // Set up starting/stopping session on application hiding/terminating
        [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(willTerminate:)
                                              name:UIApplicationWillTerminateNotification
                                              object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(willTerminate:)
                                              name:UIApplicationWillResignActiveNotification
                                              object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(willResume:)
                                              name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
	}
	return self;  
}

- (void)dealloc
{
    NSLog(@"SessionManager exiting");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [GKVoiceChatService defaultVoiceChatService].client = nil;
    if (myGKSession) [self destroySession];
	myGKSession = nil;
	sessionID = nil; 
}

#pragma mark -
#pragma mark Session logic

// Creates a GKSession and advertises availability to Peers
- (void) setupSession
{
	// GKSession will default to using the device name as the display name
	myGKSession = [[GKSession alloc] initWithSessionID:sessionID displayName:nil sessionMode:GKSessionModePeer];
	myGKSession.delegate = self; 
	[myGKSession setDataReceiveHandler:self withContext:nil]; 
	myGKSession.available = YES;
    sessionState = ConnectionStateDisconnected;
    [lobbyDelegate peerListDidChange:self];
    
}

// Initiates a GKSession connection to a selected peer.
-(void) connect:(NSString *) peerID
{
	[myGKSession connectToPeer:peerID withTimeout:10.0];
    currentConfPeerID = peerID;
    sessionState = ConnectionStateConnecting;
}

// Called from GKLobbyViewController if the user accepts the invitation alertView
-(BOOL) didAcceptInvitation
{
    NSError *error = nil;
    if (![myGKSession acceptConnectionFromPeer:currentConfPeerID error:&error]) {
        NSLog(@"%@",[error localizedDescription]);
    }

    return (gameDelegate == nil);
}

// Called from GKLobbyViewController if the user declines the invitation alertView
-(void) didDeclineInvitation
{
    // Deny the peer.
    if (sessionState != ConnectionStateDisconnected) {
        [myGKSession denyConnectionFromPeer:currentConfPeerID];
        currentConfPeerID = nil;
        sessionState = ConnectionStateDisconnected;
    }
    // Go back to the lobby if the game screen is open.
    [gameDelegate willDisconnect:self];
}

-(BOOL) comparePeerID:(NSString*)peerID
{
    return [peerID compare:myGKSession.peerID] == NSOrderedAscending;
}

// Called to check if the session is ready to start a voice chat.
-(BOOL) isReadyToStart
{
    return sessionState == ConnectionStateConnected;
}

// Called by RocketController and VoiceManager to send data to the peer
-(void) sendPacket:(NSData*)data ofType:(PacketType)type reliable:(Boolean) reliable
{
    NSMutableData * newPacket = [NSMutableData dataWithCapacity:([data length]+sizeof(uint32_t))];
    // Both game and voice data is prefixed with the PacketType so the peer knows where to send it.
    uint32_t swappedType = CFSwapInt32HostToBig((uint32_t)type);
    [newPacket appendBytes:&swappedType length:sizeof(uint32_t)];
    [newPacket appendData:data];
    NSError *error;
    GKSendDataMode mode;
    if (reliable) mode = GKSendDataReliable; else mode = GKSendDataUnreliable;
    if (currentConfPeerID) {
        if (![myGKSession sendData:newPacket toPeers:[NSArray arrayWithObject:currentConfPeerID] withDataMode:mode error:&error]) {
            NSLog(@"%@",[error localizedDescription]);
        }
    }
}

// Clear the connection states in the event of leaving a call or error.
-(void) disconnectCurrentCall
{
    [gameDelegate willDisconnect:self];
    if (sessionState != ConnectionStateDisconnected) {
        if(sessionState == ConnectionStateConnected) {
            [[GKVoiceChatService defaultVoiceChatService] stopVoiceChatWithParticipantID:currentConfPeerID];
        }
        // Don't leave a peer hangin'
        if (sessionState == ConnectionStateConnecting) {
            [myGKSession cancelConnectToPeer:currentConfPeerID];
        }
        [myGKSession disconnectFromAllPeers];
        myGKSession.available = YES;
        sessionState = ConnectionStateDisconnected;
        currentConfPeerID = nil;
    }
}

// Application is exiting or becoming inactive, end the session.
- (void)destroySession
{
    [self disconnectCurrentCall];
	myGKSession.delegate = nil;
	[myGKSession setDataReceiveHandler:nil withContext:nil];
    [peerList removeAllObjects];
}

// Called when notified the application is exiting or becoming inactive.
- (void)willTerminate:(NSNotification *)notification
{
    [self destroySession];
}

// Called after the app comes back from being hidden by something like a phone call.
- (void)willResume:(NSNotification *)notification
{
    [self setupSession];
}

#pragma mark -
#pragma mark GKSessionDelegate Methods and Helpers

// Received an invitation.  If we aren't already connected to someone, open the invitation dialog.
- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID
{
    if (sessionState == ConnectionStateDisconnected) {
        currentConfPeerID = peerID;
        sessionState = ConnectionStateConnecting;
        [lobbyDelegate didReceiveInvitation:self fromPeer:[myGKSession displayNameForPeer:peerID]];
    } else {
        [myGKSession denyConnectionFromPeer:peerID];
    }
}

// Unable to connect to a session with the peer, due to rejection or exiting the app
- (void)session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error
{
    NSLog(@"%@",[error localizedDescription]);
    if (sessionState != ConnectionStateDisconnected) {
        [lobbyDelegate invitationDidFail:self fromPeer:[myGKSession displayNameForPeer:peerID]];
        // Make self available for a new connection.
        currentConfPeerID = nil;
        myGKSession.available = YES;
        sessionState = ConnectionStateDisconnected;
    }
}

// The running session ended, potentially due to network failure.
- (void)session:(GKSession *)session didFailWithError:(NSError*)error
{
    NSLog(@"%@",[error localizedDescription]);
    [self disconnectCurrentCall];
}

// React to some activity from other peers on the network.
- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state
{
	switch (state) { 
		case GKPeerStateAvailable:
            // A peer became available by starting app, exiting settings, or ending a call.
			if (![peerList containsObject:peerID]) {
				[peerList addObject:peerID]; 
			}
 			[lobbyDelegate peerListDidChange:self]; 
			break;
		case GKPeerStateUnavailable:
            // Peer unavailable due to joining a call, leaving app, or entering settings.
            [peerList removeObject:peerID]; 
            [lobbyDelegate peerListDidChange:self]; 
			break;
		case GKPeerStateConnected:
            // Connection was accepted, set up the voice chat.
            currentConfPeerID = peerID;
            myGKSession.available = NO;
            [gameDelegate willStart:self];
            sessionState = ConnectionStateConnected;
			break;				
		case GKPeerStateDisconnected:
            // The call ended either manually or due to failure somewhere.
            [self disconnectCurrentCall];
            [peerList removeObject:peerID]; 
            [lobbyDelegate peerListDidChange:self];
			break;
        case GKPeerStateConnecting:
            // Peer is attempting to connect to the session.
            break;
		default:
			break;
	}
}

// Called when voice or game data is received over the network from the peer
- (void) receiveData:(NSData *)data fromPeer:(NSString *)peer inSession:(GKSession *)session context:(void *)context
{
    PacketType header;
    uint32_t swappedHeader;
    if ([data length] >= sizeof(uint32_t)) {    
        [data getBytes:&swappedHeader length:sizeof(uint32_t)];
        header = (PacketType)CFSwapInt32BigToHost(swappedHeader);
        NSRange payloadRange = {sizeof(uint32_t), [data length]-sizeof(uint32_t)};
        NSData* payload = [data subdataWithRange:payloadRange];
        
        // Check the header to see the packet type
        [gameDelegate session:self didReceivePacket:payload ofType:header];
    }
}

- (NSString *) displayNameForPeer:(NSString *)peerID
{
	return [myGKSession displayNameForPeer:peerID];
}

@end

