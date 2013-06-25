//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "UserInputHandler.h"
#include <Accelerate/Accelerate.h>
#import "MoveRecogniser.h"
#include <GLKit/GLKMath.h>

#include <sys/sysctl.h>


#define TRACKPAD_SENSITIVITY 4
#define MOVING_AVERAGE_WINDOW_SIZE 2
#define SEND_INTERVAL 0.2
#define LINEAR_DECEL_CONSTANT 20.0

#define IPHONE_WIDTH_MM     75.0
#define IPAD_MINI_WIDTH_MM  160.0
#define IPAD_WIDTH_MM       198.0

@implementation UserInputHandler
{
    // We keep track of local orientation to cut down on change events
    UIDeviceOrientation previousLocalOrientation;
    
    // We keep track of zoom scale between pinch gestures
    float scaleFromPreviousGesture;
    
    // We use a special gesture recogniser to track users finger swiping
    MoveRecogniser* touchPanRecogniser;
    
    // Also we track pinch gestures for pinch to zoom
    UIPinchGestureRecognizer* pinchRecogniser;
        
    // A timer is used to periodically send velocity to the recipient
    NSTimer* sendTimer;
    
    // We record velocites so they can be filtered using a moving average
    NSMutableArray* panVelocities;
    NSMutableArray* tiltVelocities;
    
    // Moving velocity averages
    int panAverage;
    int tiltAverage;
    
    // Use to scale the velocity accordingly
    double physicalScreenWidth; // in mm
    
    // Stop sending commands to device if last command was 0 == stop rotation
    bool lastSentAreZeros;
    
}


#pragma mark -
#pragma mark Initialisation & dealloc

- (id) init
{
    if (self = [super init]) {
        
        // Start listening for local device orientation changes
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(localOrientationDidChange:) name: UIDeviceOrientationDidChangeNotification object: nil];
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
                
        // Get physical screen width
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char *machine = (char*) malloc(size + 1);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        machine[size] = 0;
        
        // iPad (known models)
        if     (strcmp(machine, "iPad1,1") == 0) [self setSizeiPad];
        else if(strcmp(machine, "iPad2,1") == 0) [self setSizeiPad];
        else if(strcmp(machine, "iPad2,2") == 0) [self setSizeiPad];
        else if(strcmp(machine, "iPad2,3") == 0) [self setSizeiPad];
        else if(strcmp(machine, "iPad2,4") == 0) [self setSizeiPad];
        else if(strcmp(machine, "iPad3,1") == 0) [self setSizeiPad];
        else if(strcmp(machine, "iPad3,2") == 0) [self setSizeiPad];
        else if(strcmp(machine, "iPad3,3") == 0) [self setSizeiPad];
        else if(strcmp(machine, "iPad3,4") == 0) [self setSizeiPad];
        else if(strcmp(machine, "iPad3,5") == 0) [self setSizeiPad];
        else if(strcmp(machine, "iPad3,6") == 0) [self setSizeiPad];
        
        // iPad mini (known models)
        else if(strcmp(machine, "iPad2,5") == 0) [self setSizeiPadMini];
        else if(strcmp(machine, "iPad2,6") == 0) [self setSizeiPadMini];
        else if(strcmp(machine, "iPad2,7") == 0) [self setSizeiPadMini];
        
        // iPad mini (possible future models)
        else if(strncmp(machine, "iPad2,", 6) == 0) ;
        
        // iPad (possible future models)
        else if(strncmp(machine, "iPad", 4) == 0) [self setSizeiPad];
        
        // iPhone, iPod and anything else
        else [self setSizeiPhone];
        
        free(machine);
        
        // Create empty velocity queues
        panVelocities = [[NSMutableArray alloc] initWithCapacity:30];
        tiltVelocities = [[NSMutableArray alloc] initWithCapacity:30];
        
        // Add touch handler for when finger is panned across the view
        touchPanRecogniser = [[MoveRecogniser alloc] initWithTarget:self action:@selector(handleTouchMove:)];
        [touchPanRecogniser setMaximumNumberOfTouches:1];
        
        // Default vals
        lastSentAreZeros = true;
        
        // Add touch handler for two finger pinch
        pinchRecogniser = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
        scaleFromPreviousGesture = 1.0;
        
    }
    return self;
}

- (void) setViewForGestureInput:(UIView *)viewForGestureInput
{
    // Remove recogniser from previous
    if (_viewForGestureInput != nil) {
        [_viewForGestureInput removeGestureRecognizer:touchPanRecogniser];
    }
    
    // Update to new view
    _viewForGestureInput = viewForGestureInput;
    
    // Add recognisers and enable interaction
    [_viewForGestureInput addGestureRecognizer:touchPanRecogniser];
    [_viewForGestureInput addGestureRecognizer:pinchRecogniser];
    [_viewForGestureInput setUserInteractionEnabled:YES];
}

- (void) dealloc
{
    NSLog(@"UserInput exiting");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    _networkControllerDelegate = nil;
    _orientationUpdateResponder = nil;
    _viewForGestureInput = nil;
}

#pragma mark -
#pragma mark Handle different screen sizes

- (void) setSizeiPad
{
    physicalScreenWidth = IPAD_WIDTH_MM;
}
- (void) setSizeiPadMini
{
    physicalScreenWidth = IPAD_MINI_WIDTH_MM;
}
- (void) setSizeiPhone
{
    physicalScreenWidth = IPHONE_WIDTH_MM;
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
    [_orientationUpdateResponder localOrientationDidChange:orientation];
    [_networkControllerDelegate sendOrientationUpdate:orientation];
    previousLocalOrientation = orientation;

}

#pragma mark -
#pragma mark Handle movement gestures

- (void) handleTouchMove: (UIPanGestureRecognizer *) sender
{
    // Setup timer if not already done so
    if (sendTimer == nil) {
        sendTimer = [NSTimer timerWithTimeInterval:SEND_INTERVAL target:self selector:@selector(sendTimerFire) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:sendTimer forMode:NSRunLoopCommonModes];
    }
    
    // Get the velocity of the drag
    CGPoint velocity = [sender velocityInView: self.viewForGestureInput];
    
    // Scale according to physical screen dimensions
    signed int px = velocity.y * (IPHONE_WIDTH_MM / physicalScreenWidth);
    signed int py = -velocity.x * (IPHONE_WIDTH_MM / physicalScreenWidth);
    
    // Also scale using zoom constant, to ensure movement slows down at higher zoom levels
    double zoomConstant = 70.0;
    px = px / ((((scaleFromPreviousGesture-1.0)/99.0)*zoomConstant)+1.0);
    py = py / ((((scaleFromPreviousGesture-1.0)/99.0)*zoomConstant)+1.0);
    
    // Normalise to correct range
    px = (TRACKPAD_SENSITIVITY*px) / 35;
    py = (TRACKPAD_SENSITIVITY*py) / 35;
    if (px > 100) px = 100;
    if (px < -100) px = -100;
    if (py > 100) py = 100;
    if (py < -100) py = -100;
    
    if (sender.state == UIGestureRecognizerStateBegan) {
        panAverage = 0;
        tiltAverage = 0;
    }
    else if (sender.state == UIGestureRecognizerStateChanged) {
        
        // During movement, send the velocity vector
        @synchronized (self) {
            
            // Add data point to velocity window, drop old data point if no room
            [panVelocities insertObject: [NSNumber numberWithInt:px ] atIndex: [panVelocities count]];
            if ([panVelocities count] > MOVING_AVERAGE_WINDOW_SIZE) [panVelocities removeObjectAtIndex:0];
            [tiltVelocities insertObject: [NSNumber numberWithInt:py ] atIndex: [tiltVelocities count]];
            if ([tiltVelocities count] > MOVING_AVERAGE_WINDOW_SIZE) [tiltVelocities removeObjectAtIndex:0];
            
            // Recalculate moving average
            [self calculateMovingAverage];
            
        }
        
    }
    else if (sender.state == UIGestureRecognizerStateEnded) {
        
        // At the end of the gesture, wipe the velocity windows
        @synchronized (self) {
            [panVelocities removeAllObjects];
            [tiltVelocities removeAllObjects];
        }
        
    }
    
    
}

- (void) calculateMovingAverage
{
    int panSum = 0;
    for (NSNumber *pan in panVelocities) panSum += [pan intValue];
    panAverage = panSum / (int)[panVelocities count];
    
    int tiltSum = 0;
    for (NSNumber *tilt in tiltVelocities) tiltSum += [tilt intValue];
    tiltAverage = tiltSum / (int)[tiltVelocities count];
}

#pragma mark -
#pragma mark Handle pinch gestures

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
    
    [_networkControllerDelegate sendZoomFactor: [NSNumber numberWithFloat: newScale ]];
    
    // At the end of the gesture, store the scale
    if (sender.state == UIGestureRecognizerStateEnded) {
        scaleFromPreviousGesture = newScale;
    }
}

#pragma mark -
#pragma mark Send commands to remote

- (void) sendTimerFire
{
    @synchronized (self)
    {
        // Send filtered averages
        //NSLog(@"Pan %i, tilt %i", panAverage, tiltAverage);
        [self sendGalileoControlWithPan:panAverage tilt:tiltAverage];
        
        // Decelerate
        if (abs(panAverage) > LINEAR_DECEL_CONSTANT) panAverage -= (panAverage>0?1:-1) * LINEAR_DECEL_CONSTANT;
        else panAverage = 0;
        if (abs(tiltAverage) > LINEAR_DECEL_CONSTANT) tiltAverage -= (tiltAverage>0?1:-1) * LINEAR_DECEL_CONSTANT;
        else tiltAverage = 0;
        
    }
}

- (void) sendGalileoControlWithPan: (int) panAmount
                             tilt : (int) tiltAmount
{
    int pan = panAmount;
    int tilt = tiltAmount;
    
    if (pan > 100) pan = 100;
    if (pan < -100) pan = -100;
    if (tilt > 100) tilt = 100;
    if (tilt < -100) tilt = -100;
    
    // zeros are enough to be sent once
    if (lastSentAreZeros && pan == tilt && pan == 0)
        return;
    
    NSNumber *panNumber = [NSNumber numberWithDouble:pan];
    NSNumber *tiltNumber = [NSNumber numberWithDouble:tilt];
    [_networkControllerDelegate sendGalileoControlWithPan:panNumber ignore:NO tilt:tiltNumber ignore:NO momentum:NO];
    
    lastSentAreZeros = pan == tilt && pan == 0;
}

@end










