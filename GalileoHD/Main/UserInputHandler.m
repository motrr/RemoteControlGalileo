//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "UserInputHandler.h"
#import "TouchBeganRecogniser.h"
#include <Accelerate/Accelerate.h>

#include <GLKit/GLKMath.h>

#define MAX_TOUCH_IDLE_PERIOD 0.1
#define TRACKPAD_SENSITIVITY 3

@implementation UserInputHandler

@synthesize networkControllerDelegate;
@synthesize orientationUpdateResponder;
@synthesize viewForGestureInput;

- (id) init
{
    if (self = [super init]) {
        
        // Start listening for local device orientation changes
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(localOrientationDidChange:) name: UIDeviceOrientationDidChangeNotification object: nil];
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
                
        // Add gesture recogniser for when touch first begins
        TouchBeganRecogniser* touchBeganRecogniser = [[TouchBeganRecogniser alloc]  initWithTarget:self action:@selector(handleTouchBegan:)];
        //[self.viewForGestureInput addGestureRecognizer:touchBeganRecogniser];
        
        // Add touch handler for when finger is panned across the view
        UIPanGestureRecognizer* touchPanRecogniser = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTouchPan:)];
        [touchPanRecogniser setMaximumNumberOfTouches:1];
        [self.viewForGestureInput addGestureRecognizer:touchPanRecogniser];
        
        // Add touch handler for two finger pinch
        UIPinchGestureRecognizer* pinchRecogniser = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
        scaleFromPreviousGesture = 1.0;
        [self.viewForGestureInput addGestureRecognizer:pinchRecogniser];
        
        // Enable interaction
        [self.viewForGestureInput setUserInteractionEnabled:YES];
        
    }
    return self;
}


- (void) dealloc
{
    NSLog(@"UserInput exiting");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    networkControllerDelegate = nil;
    orientationUpdateResponder = nil;
    viewForGestureInput = nil;
}


#pragma mark -
#pragma mark Detect orientation changes

- (void) localOrientationDidChange:(NSNotification *)notification {
    
    // Obtain the current device orientation
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    
    // Ignore specific orientations
    if (orientation == UIDeviceOrientationFaceUp || orientation == UIDeviceOrientationFaceDown || orientation == UIDeviceOrientationUnknown || previousLocalOrientation == orientation) {
        return;
    }
    
    NSLog( @"Valid local orientation change detected" );
    
    // Call orientation changed responder, notify remote over network and remember new orientation for next time
    [orientationUpdateResponder localOrientationDidChange:orientation];
    [networkControllerDelegate sendOrientationUpdate:orientation];
    previousLocalOrientation = orientation;

}

#pragma mark -
#pragma mark Handle touch gestures

// When the view is first touched we must send a stop command
- (void) handleTouchBegan:(UILongPressGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        // Send zero velocity vector
        [networkControllerDelegate sendGalileoControlWithPan:0 ignore:NO tilt:0 ignore:NO momentum:YES];
    }
    timeOfLastGestureEvent = [NSDate date]; // log current time
    
}

// If touch is idle for a specified period we must send a stop command
- (void) handleTouchTimout
{
    // Get the time since the last gesture
    NSTimeInterval timeSinceLastGestureEvent = [timeOfLastGestureEvent timeIntervalSinceNow];
    
    // If greater than idle period passed with no movement, send a zero vector
    if (-timeSinceLastGestureEvent > MAX_TOUCH_IDLE_PERIOD ) {
        
        // Send zero velocity vector
        [networkControllerDelegate sendGalileoControlWithPan:0 ignore:NO tilt:0 ignore:NO momentum:YES];
    }
}

// When the finger pans across the view we perform different actions at the start, finish and during the gesture.
- (void) handleTouchPan: (UIPanGestureRecognizer *) sender
{
    // Get the velocity of the drag
    CGPoint velocity = [sender velocityInView: self.viewForGestureInput];
    
    // Normalise to correct range
    signed int px = (TRACKPAD_SENSITIVITY*velocity.x) / 35;
    signed int py = (TRACKPAD_SENSITIVITY*velocity.y) / 35;
    if (px > 100) px = 100;
    if (px < -100) px = -100;
    if (py > 100) py = 100;
    if (py < -100) py = -100;
    
    if (sender.state == UIGestureRecognizerStateBegan) {
        
        // At the start of the gesture schedule subsequent periodic timout after idle time
        gestureTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:MAX_TOUCH_IDLE_PERIOD target:self selector:@selector(handleTouchTimout) userInfo:nil repeats:YES];
        // Lock local orientation reponses
        [orientationUpdateResponder lockOrientationResponse];
        
        
    }
    else if (sender.state == UIGestureRecognizerStateChanged) {
        
        // During movement, send the velocity vector
        [networkControllerDelegate sendGalileoControlWithPan:[NSNumber numberWithInt:-py] ignore:NO
                                                        tilt:[NSNumber numberWithInt:-px] ignore:NO
                                                    momentum:YES];
        
    }
    else if (sender.state == UIGestureRecognizerStateEnded) {
        
        // At the end of the gesture, invalidate the timout timer
        [gestureTimeoutTimer invalidate];
        gestureTimeoutTimer = nil;
        
        // We only wish to impart momemtum above a specific threshold
        unsigned int thresh1 = 9000;
        unsigned int thresh2 = 5000;
        
        // If we don't have *two* very big movements
        if ( abs(px) < thresh1 || abs(py) < thresh1 ) {
            
            // Stop movement in the smallest direction
            if ( abs(px) > abs(py)) py = 0; else px = 0;
            
            // Only throw big movements anyway
            if ( abs(px) < thresh2 ) px = 0;
            if ( abs(py) < thresh2 ) py = 0;
        }
        
        // Send remaining velocity (likely to be zero) vector
        [networkControllerDelegate sendGalileoControlWithPan: [NSNumber numberWithInt:0] ignore:NO 
                                                        tilt: [NSNumber numberWithInt:0] ignore:NO
                                                    momentum: YES];
        
        // Unlock local orientation reponses
        [orientationUpdateResponder unlockOrientationResponse];
    }
    
    timeOfLastGestureEvent = [NSDate date]; // log current time
}

- (void) handlePinch: (UIPinchGestureRecognizer *) sender
{
    float newScale;
    
    if (scaleFromPreviousGesture * sender.scale < 1.0) {
        newScale = 1.0;
    }
    else if (scaleFromPreviousGesture * sender.scale > 100.0) {
        newScale = 100.0;
    }
    else {
        newScale = scaleFromPreviousGesture * sender.scale;
    }
    
    [networkControllerDelegate sendZoomFactor: [NSNumber numberWithFloat: newScale ]];
    
    // At the end of the gesture, store the scale
    if (sender.state == UIGestureRecognizerStateEnded) {
        scaleFromPreviousGesture = newScale;
    }
}

@end










