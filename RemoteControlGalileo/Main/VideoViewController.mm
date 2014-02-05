//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoViewController.h"
#import "VideoView.h"

#import <QuartzCore/CALayer.h>

#define ROTATION_ANIMATION_DURATION 0.5

@implementation VideoViewController

@synthesize networkControllerDelegate;

#pragma mark -
#pragma mark Initialisation and view life cycle

- (id)init
{
    if(self = [super init])
    {
        isLocked = NO;
        isRotated180 = NO;
    }
    
    return self;
}

- (void)dealloc
{
    NSLog(@"VideoViewController exiting");
}

- (void)loadView
{
    // Create the view which will show the received video
    self.wantsFullScreenLayout = YES;
    self.view = [[VideoView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    //[self.view.layer setMagnificationFilter:kCAFilterTrilinear];
    [self.view setBackgroundColor:[UIColor blackColor]];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

#pragma mark -
#pragma mark OrientationUpdateResponderDelegate methods

- (void)logOrientation:(UIDeviceOrientation)orientation message:(NSString *)message
{
    if(orientation == UIDeviceOrientationLandscapeLeft)
        NSLog(@"%@: UIDeviceOrientationLandscapeLeft", message);
    else if(orientation == UIDeviceOrientationLandscapeRight)
        NSLog(@"%@: UIDeviceOrientationLandscapeRight", message);
    else if(orientation == UIDeviceOrientationPortrait)
        NSLog(@"%@: UIDeviceOrientationPortrait", message);
    else if(orientation == UIDeviceOrientationPortraitUpsideDown)
        NSLog(@"%@: UIDeviceOrientationPortraitUpsideDown", message);
    else
        NSLog(@"%@: unknown", message);
}

// Helper method run when either changes
- (void)localOrRemoteOrientationDidChange
{
    //[self logOrientation:currentLocalOrientation message:@"local"];
    //[self logOrientation:currentRemoteOrientation message:@"remote"];
    
    if (!isRotated180)
    {
        // Only do anything if 180 disparity between local and remote
        if ((    currentLocalOrientation == UIDeviceOrientationLandscapeLeft
             && currentRemoteOrientation == UIDeviceOrientationLandscapeRight)
            ||
            (    currentLocalOrientation == UIDeviceOrientationLandscapeRight
             && currentRemoteOrientation == UIDeviceOrientationLandscapeLeft)
            ||
            (    currentLocalOrientation == UIDeviceOrientationPortrait
             && currentRemoteOrientation == UIDeviceOrientationPortraitUpsideDown)
            ||
            (    currentLocalOrientation == UIDeviceOrientationPortraitUpsideDown 
             && currentRemoteOrientation == UIDeviceOrientationPortrait))
        {
            isRotated180 = YES;
            [UIView animateWithDuration: ROTATION_ANIMATION_DURATION
                             animations:^ {
                                 self.view.transform = CGAffineTransformMakeRotation(M_PI);
                             }
             ];
        }
        // Rotate screen by -180 to reach same result when one device in landscape right or left mode
        // and another in upside down mode
        else if (currentRemoteOrientation == UIDeviceOrientationPortraitUpsideDown
                 &&
                 (   currentLocalOrientation == UIDeviceOrientationLandscapeLeft
                  || currentLocalOrientation == UIDeviceOrientationLandscapeRight))
        {
            isRotated180 = YES;
            [UIView animateWithDuration: ROTATION_ANIMATION_DURATION
                             animations:^ {
                                 self.view.transform = CGAffineTransformMakeRotation(-M_PI);
                             }
             ];
        }
    }
    else if(isRotated180)
    {
        // We dont want any jumping here, so lets just return back when 1 to 1 mapping
        if (currentLocalOrientation == currentRemoteOrientation)
        {
            isRotated180 = NO;
            [UIView animateWithDuration: ROTATION_ANIMATION_DURATION
                             animations:^ {
                                 self.view.transform = CGAffineTransformIdentity;
                             }
             ];
        }
    }
}

- (void)remoteOrientationDidChange:(UIDeviceOrientation)newOrientation
{
    currentRemoteOrientation = newOrientation;
    if (!isLocked) [self localOrRemoteOrientationDidChange];
}

- (void)localOrientationDidChange:(UIDeviceOrientation)newOrientation
{
    currentLocalOrientation = newOrientation;
    if (!isLocked) [self localOrRemoteOrientationDidChange]; 
}

- (void)lockOrientationResponse
{
    isLocked = YES;
}

- (void)unlockOrientationResponse
{
    isLocked = NO;
    [self localOrRemoteOrientationDidChange];
}

@end
