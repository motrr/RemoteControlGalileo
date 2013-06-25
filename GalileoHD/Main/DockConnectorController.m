//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "DockConnectorController.h"
#import <GalileoControl/GalileoControl.h>
#import "VideoTxRxCommon.h"

@implementation DockConnectorController

#pragma mark -
#pragma mark Initialisation and serial port setup

- (id) init
{
    if (self = [super init]) {
        
        // Watch out for rotations
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        
        // Wait for Galileo to connect
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(galileoDidDisconnect) name:GalileoDidDisconnectNotification object:nil];
        [[Galileo sharedGalileo] waitForConnection];
        
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"SerialController exiting");
    //[PreMFiGalileoController disconnectFromGalileo];
}

#pragma mark -
#pragma mark GalleoDelegate methods

- (void) GalileoDidDisconnectNotification
{
    [[Galileo sharedGalileo] waitForConnection];
}


#pragma mark -
#pragma mark GalileoControlResponderDelegate methods

- (void) galileoControlCommandRecievedWithPan: (NSNumber*) panAmount  ignore: (Boolean) ignorePan
                                         tilt: (NSNumber*) tiltAmount ignore: (Boolean) ignoreTilt
                                     momentum:(bool)momentum
{
    // Watch out for ignore flags (which signal no new velocity should be sent)
    
    if ([[Galileo sharedGalileo] isConnected]) {
        
        double panVelocity = [panAmount doubleValue] * (-1);
        double tiltVelocity = [tiltAmount doubleValue] * (-1);
        
        int tiltModifier = ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationLandscapeLeft ? -1 : 1);
        
        // Invert direction for rear camera
        tiltModifier *= (FORCE_REAR_CAMERA == YES) ? 1 : -1;
        
        Galileo *galileo = [Galileo sharedGalileo];
        
        // Pan
        [[galileo velocityControlForAxis:GalileoControlAxisPan] setTargetVelocity:panVelocity];
        
        // Move tilt panel only if is in landscape
        BOOL isLandscape = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
        if (isLandscape)
            [[galileo velocityControlForAxis:GalileoControlAxisTilt] setTargetVelocity:tiltVelocity * tiltModifier];
        

        [[[Galileo sharedGalileo] velocityControlForAxis:GalileoControlAxisPan] setTargetVelocity:[panAmount floatValue]];
        [[[Galileo sharedGalileo] velocityControlForAxis:GalileoControlAxisTilt] setTargetVelocity:[tiltAmount floatValue]];
        
    }
}



@end
