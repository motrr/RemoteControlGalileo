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
}


#pragma mark -
#pragma mark OrientationUpdateResponderDelegate methods

// Helper method run when either changes
- (void)localOrRemoteOrientationDidChange
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
        [UIView animateWithDuration: ROTATION_ANIMATION_DURATION
                         animations:^ {
                             self.view.transform = CGAffineTransformMakeRotation(M_PI);
                         }
         ];
    }
    else
    {
        [UIView animateWithDuration: ROTATION_ANIMATION_DURATION
                         animations:^ {
                             self.view.transform = CGAffineTransformIdentity;
                         }
         ];
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
