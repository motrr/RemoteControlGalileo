//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Listens for image frames on a UDP socket and displays them on a view. Must respond to local and remote orientation changes. Also, the network controller is used to transmit local IP address when creating the UDP socket.

#import <UIKit/UIKit.h>
#import "GalileoCommon.h"
#import "MediaOutput.h"

#define NOTIFICATION_TOGGLE_RECORDING_MODE @"NOTIFICATION_TOGGLE_RECORDING_MODE"

@class VideoView;

@interface VideoViewController : UIViewController <OrientationUpdateResponderDelegate, RecordStatusResponderDelegate>
{
    // Keep track of local and remote orientation
    UIDeviceOrientation currentLocalOrientation;
    UIDeviceOrientation currentRemoteOrientation;
    BOOL isRotated180;
    
    // Lock when busy
    BOOL isLocked;
    
    // Button for recording
    UIButton *recordButton;
    UILabel *labelRecordStatus;
    UILabel *labelRTCPStatus;
    BOOL isRecording;

    NSTimer *timer;
    NSDate *timerStartTime;
    NSCalendar *calendar;
    BOOL showTimerColon;

    VideoView *videoView;

    NSString *osdVideoDescription;
    NSString *osdAudioDescription;
}

@property (nonatomic, weak) id<NetworkControllerDelegate> networkControllerDelegate;
@property (nonatomic, weak) MediaOutput *mediaOutput;

- (VideoView *)videoView;

@end
