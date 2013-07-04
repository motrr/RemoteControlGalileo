//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 motrr, LLC. All rights reserved.
//

#import "MoveRecogniser.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

#define MAX_TOUCH_IDLE_PERIOD 0.1

@implementation MoveRecogniser
{
    CGPoint initialPosition;
    CGPoint previousPosition;
    CGPoint latestPosition;
    NSTimeInterval previousTimestamp;
    NSTimeInterval latestTimestamp;
    
    NSTimer* timoutTimer;
}

- (id)initWithTarget:(id)target action:(SEL)action
{
    if ((self=[super initWithTarget:target action:action])) {
        _minimumNumberOfTouches = 1;
        _maximumNumberOfTouches = NSUIntegerMax;
    }
    return self;
}

# pragma -
# pragma mark Public methods

- (CGPoint)translationInView:(UIView *)view
{
    if ([self isGestureInProgress]) {
        
        CGPoint initialPositionInView = [self.view convertPoint:initialPosition toView:view];
        CGPoint latestPositionInView = [self.view convertPoint:latestPosition toView:view];
        return [self subtract: initialPositionInView fromPoint: latestPositionInView];
        
    }
    else return CGPointZero;
}

- (CGPoint)velocityInView:(UIView *)view
{
    if ([self isGestureInProgress]) {
        
        CGPoint previousPositionInView = [self.view convertPoint:previousPosition toView:view];
        CGPoint latestPositionInView = [self.view convertPoint:latestPosition toView:view];
        CGPoint positionDelta = [self subtract: previousPositionInView fromPoint: latestPositionInView];
        NSTimeInterval timeDelta = latestTimestamp - previousTimestamp;

        CGPoint velocity;
        if (timeDelta != 0) {
            velocity.x = positionDelta.x / timeDelta;
            velocity.y = positionDelta.y / timeDelta;
        }
        else velocity = CGPointZero;
        return velocity;
        
    }
    else return CGPointZero;
}

- (CGPoint) subtract: (CGPoint) pointA fromPoint: (CGPoint) pointB
{
    CGPoint delta;
    delta.x = pointB.x - pointA.x;
    delta.y = pointB.y - pointA.y;
    return delta;
}

- (BOOL) isGestureInProgress
{
    return (self.state == UIGestureRecognizerStateChanged);
}


# pragma -
# pragma mark Interaction with other recognisers

- (BOOL) canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer
{
    return NO;
}

- (BOOL) canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer
{
    return NO;
}

# pragma -
# pragma mark Detecting position & velocity

- (void) gestureStarted: (UITouch*) touch
{
    // Record the position
    initialPosition = [touch locationInView:self.view];
    
    // Set this as the latest position also
    latestPosition = [touch locationInView:self.view];
    latestTimestamp = [touch timestamp];
}

- (void) gestureUpdated: (UITouch*) touch
{
    // Latest now become previous
    previousPosition = latestPosition;
    previousTimestamp = latestTimestamp;

    // Get new latest from the incoming touch
    latestPosition = [touch locationInView:self.view];
    latestTimestamp = [touch timestamp];
}


# pragma -
# pragma mark Touch event handlers

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Check we are using only one finger
    if (([[event allTouches] count] <= _maximumNumberOfTouches) &&
        ([[event allTouches] count] >= _minimumNumberOfTouches)) {
        
        // If possible, begin the gesture
        if (self.state == UIGestureRecognizerStatePossible) {
            [self gestureStarted: [[event allTouches] anyObject]];
            self.state = UIGestureRecognizerStateBegan;
        }
        else [self finishGesture];
    }
    else [self finishGesture];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Check we are using only one finger
    if (([[event allTouches] count] <= _maximumNumberOfTouches) &&
        ([[event allTouches] count] >= _minimumNumberOfTouches)) {
        
        // Gesture advances
        if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
            
            // Update state given the new touch
            [self gestureUpdated: [[event allTouches] anyObject]];
            self.state = UIGestureRecognizerStateChanged;
            
            // Ensure that update is called again after a specific timeout period, even if no movement occurs
            [timoutTimer invalidate];
            timoutTimer = [NSTimer scheduledTimerWithTimeInterval:MAX_TOUCH_IDLE_PERIOD target:self selector:@selector(touchTimeOut) userInfo:nil repeats:NO];
            
        }
        else [self finishGesture];
    }
    else  [self finishGesture];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
     [self finishGesture];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self finishGesture];
}

- (void) finishGesture
{
    if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
        self.state = UIGestureRecognizerStateEnded;
    }
    self.state = UIGestureRecognizerStateFailed;
}


# pragma -
# pragma mark Generating extra updates

- (void) touchTimeOut
{
    // Gesture advances
    if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
        
        // Update state, movement has basically stopped
        previousPosition = latestPosition;
        self.state = UIGestureRecognizerStateChanged;
        
    }
}


@end
