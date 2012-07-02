//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Listens for image frames on a UDP socket and displays them on a view. Must respond to local and remote orientation changes. Also, the network controller is used to transmit local IP address when creating the UDP socket.

#import <UIKit/UIKit.h>
#import "GalileoCommon.h"

@class VideoDecoder;

@interface VideoViewController : UIViewController <OrientationUpdateResponderDelegate>
{
    // BSD sockets
    u_short port;
    unsigned int videoRxSocket;
    
    // AV reception
    NSData* imageData;
    
    // Video decoder object
    VideoDecoder* videoDecoder;
    
    // Keep track of local and remote orientation
    UIDeviceOrientation currentLocalOrientation;
    UIDeviceOrientation currentRemoteOrientation;
    
    // Lock when busy
    BOOL isLocked;
    
    // Button for recording
    UIButton* recordButton;
    BOOL isRecording;
    
}

@property (nonatomic, weak) id<NetworkControllerDelegate> networkControllerDelegate;

- (void) openSocket;
- (void) startListeningForVideo;

@end