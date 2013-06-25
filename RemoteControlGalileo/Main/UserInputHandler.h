//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Detects touch gestures for Galileo control on a view. Also listens for orientation updates. The network controller is used to send events to the remote device.

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import "GalileoCommon.h"
#import "DockConnectorController.h"


@interface UserInputHandler : NSObject <UIAccelerometerDelegate>

@property (nonatomic, weak) id<NetworkControllerDelegate> networkControllerDelegate;
@property (nonatomic, weak) id<OrientationUpdateResponderDelegate> orientationUpdateResponder;
@property (nonatomic, weak) UIView* viewForGestureInput;

@end
