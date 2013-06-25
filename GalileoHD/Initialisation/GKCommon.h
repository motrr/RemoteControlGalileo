//  Created by Chris Harding on 02/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Protocols and constants common to GK classes

#import <Foundation/Foundation.h>

#pragma mark -
#pragma mark Connection state delegate protocol

typedef enum {
    PacketTypeIpAddress = 0,
    PacketTypeOrientationChanged = 1,
    PacketTypeControl = 2,
    PacketTypeZoom = 3,
    PacketTypePing = 4,
    PacketTypePong = 5,
    PacketTypeRecord = 6
} PacketType;

typedef enum {
    ConnectionStateDisconnected,
    ConnectionStateConnecting,
    ConnectionStateConnected
} ConnectionState;

@class GKSessionManager;

@protocol ConnectionStateResponderDelegate <NSObject>

- (void) peerSelected;
- (void) connectionIsNowAlive;
- (void) connectionIsDead;

@end

@protocol SessionManagerLobbyDelegate

- (void) peerListDidChange:(GKSessionManager *)session;
- (void) didReceiveInvitation:(GKSessionManager *)session fromPeer:(NSString *)participantID;
- (void) invitationDidFail:(GKSessionManager *)session fromPeer:(NSString *)participantID;

@end

@protocol SessionManagerGameDelegate

- (void) willStart:(GKSessionManager *)session;
- (void) willDisconnect:(GKSessionManager *)session;
- (void) session:(GKSessionManager *)session didReceivePacket:(NSData*)data ofType:(PacketType)packetType;

@end