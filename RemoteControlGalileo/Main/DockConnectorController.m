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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(galileoDidDisconnect) name:GCDidDisconnectNotification object:nil];
        [[GCGalileo sharedGalileo] waitForConnection];
        
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
    [[GCGalileo sharedGalileo] waitForConnection];
}


#pragma mark -
#pragma mark GalileoControlResponderDelegate methods

- (void) galileoControlCommandRecievedWithPan: (NSNumber*) panAmount  ignore: (Boolean) ignorePan
                                         tilt: (NSNumber*) tiltAmount ignore: (Boolean) ignoreTilt
                                     momentum:(bool)momentum
{
    // Watch out for ignore flags (which signal no new velocity should be sent)
    
    if ([[GCGalileo sharedGalileo] isConnected]) {
        
        double panVelocity = [panAmount doubleValue];
        double tiltVelocity = [tiltAmount doubleValue];

        int tiltModifier = 1;
        int panModifier = 1;

        UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;

        if (FORCE_REAR_CAMERA)
        {
            tiltModifier = 1;
            panModifier = deviceOrientation == UIDeviceOrientationLandscapeLeft ? -1 : 1;
        }
        else
        {
            tiltModifier = 1;
            panModifier = deviceOrientation == UIDeviceOrientationLandscapeLeft ? 1 : -1;
        }


        GCGalileo *galileo = [GCGalileo sharedGalileo];
        
        // Pan
        [[galileo velocityControlForAxis:GCControlAxisPan] setTargetVelocity:panVelocity * panModifier];

        // Move tilt panel only if is in landscape
        BOOL isLandscape = !UIDeviceOrientationIsPortrait(deviceOrientation);
        if (isLandscape)
            [[galileo velocityControlForAxis:GCControlAxisTilt] setTargetVelocity:tiltVelocity * tiltModifier];

    }
}



@end
