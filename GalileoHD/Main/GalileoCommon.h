//  Created by Chris Harding on 02/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Constants and also protocols for responding to incoming packets and for generating outgoing packets.

#import <Foundation/Foundation.h>

// UDP port used for transmitting audio/video
#define AV_UDP_PORT 1234

// Size of UDP buffers for transmiting audio/video
#define AV_UDP_BUFFER_LEN 15000

// Forward declarations
@protocol NetworkControllerDelegate;
@protocol VideoConfigResponderDelegate;
@protocol OrientationUpdateResponderDelegate;
@protocol GalileoControlResponderDelegate;


#pragma mark -
#pragma mark Network controller delegate protocol

@protocol NetworkControllerDelegate <NSObject>

/*
 To recieve messages, objects can set themselves as the controller's delegate
 */

@property (nonatomic, weak) id <VideoConfigResponderDelegate> videoConfigResponder;
@property (nonatomic, weak) id <OrientationUpdateResponderDelegate> orientationUpdateResponder;
@property (nonatomic, weak) id <GalileoControlResponderDelegate> galileoControlResponder;


/*
 To send messages, objects can use the controller's send methods
 */

// Send ping (or ping response) packet for link estimation
- (void) sendPing;
- (void) sendPong: (UInt16) recievedPingIndex;
// Send local IP address to use for broadcasting video
- (void) sendIpAddress;
// Send an orientation changed event to ensure display is correct way up
- (void) sendOrientationUpdate: (UIDeviceOrientation) orientation;
// Send a command to control remote Galileo
- (void) sendGalileoControlWithPan: (NSNumber*) panAmount ignore: (Boolean) ignorePan
                             tilt : (NSNumber*) tiltAmount ignore: (Boolean) ignoreTilt
                          momentum:(bool)momentum;
// Send a command to zoom in on the remote Galileo
- (void) sendZoomFactor: (NSNumber*) scale;
// Send command to start/stop recording
- (void) sendRecordCommand: (Boolean) startRecording;

@end


#pragma mark -
#pragma mark Sub-component delegate protocols

@protocol VideoConfigResponderDelegate <NSObject>

// Handle reception of an IP address from the remote device
- (void) ipAddressRecieved: (NSString*) addressString;

- (void) zoomLevelUpdateRecieved: (NSNumber*) scaleFactor;
- (void) startRecording;
- (void) stopRecording;

@end


@protocol OrientationUpdateResponderDelegate <NSObject>

// Handle a change in orientation of the remote or local device
- (void) remoteOrientationDidChange: (UIDeviceOrientation) newOrientation; 
- (void)  localOrientationDidChange: (UIDeviceOrientation) newOrientation;

// Lock and unlock the orientation update responder
- (void) lockOrientationResponse;
- (void) unlockOrientationResponse;

@end


@protocol GalileoControlResponderDelegate <NSObject>

// Handle reception of a Galileo control command
- (void) galileoControlCommandRecievedWithPan: (NSNumber*) panAmount  ignore: (Boolean) ignorePan
                                         tilt: (NSNumber*) tiltAmount ignore: (Boolean) ignoreTilt
                        momentum:(bool) momentum;


@end
