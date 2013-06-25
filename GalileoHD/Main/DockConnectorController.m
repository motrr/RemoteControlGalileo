//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "DockConnectorController.h"

@implementation DockConnectorController

#pragma mark -
#pragma mark Initialisation and serial port setup

- (id) init
{
    if (self = [super init]) {
        
        // Connect to Galileo, currently using the non-MFi method which requires (amongst other things) a jailbroken iOS device.
        //NSError* error;
        //[PreMFiGalileoController connectToGalileo: &error ];
        //if (error) NSLog(@"Error connecting to physical Galileo device. Ensure Galileo is plugged in.");
        
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"SerialController exiting");
    //[PreMFiGalileoController disconnectFromGalileo];
}

#pragma mark -
#pragma mark GalileoControlResponderDelegate methods

- (void) galileoControlCommandRecievedWithPan: (NSNumber*) panAmount  ignore: (Boolean) ignorePan
                                         tilt: (NSNumber*) tiltAmount ignore: (Boolean) ignoreTilt
                                     momentum:(bool)momentum
{
    // Watch out for ignore flags (which signal no new velocity should be sent)
    //[PreMFiGalileoController panGalileoAtSpeed: [panAmount floatValue]];
    //[PreMFiGalileoController panGalileoAtSpeed: [tiltAmount floatValue]];
}



@end
