//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoViewController.h"
#import  <QuartzCore/CALayer.h>

#import "VideoTxRxCommon.h"
#import "VideoDepacketiser.h"
#import "VideoView.h"

#define ROTATION_ANIMATION_DURATION 0.5

@implementation VideoViewController

@synthesize networkControllerDelegate;


#pragma mark -
#pragma mark Initialisation and view life cycle

- (id) init
{
    if (self = [super init]) {
        
        isLocked = NO;
        
    }
    return self;
    
}

- (void) dealloc
{
    NSLog(@"VideoViewController exiting");
}

- (void) loadView
{
    // Create the view which will show the received video
    self.wantsFullScreenLayout = YES;
    self.view = [[VideoView alloc]
                 initWithFrame:[UIScreen mainScreen].applicationFrame];
    //[self.view.layer setMagnificationFilter:kCAFilterTrilinear];
    [self.view setBackgroundColor:[UIColor blackColor]];
    
    // Add the view to the depacketiser so it can display completed frames upon it
    videoDepacketiser = [[VideoDepacketiser alloc] init];
    videoDepacketiser.viewForDisplayingFrames = (VideoView*)self.view;
    
}


- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    
    return NO;
}


- (void) viewWillAppear:(BOOL)animated
{
    // Create socket to listen out for video transmission
    [videoDepacketiser openSocket];

    // Start listening in the background
    [NSThread detachNewThreadSelector: @selector(startListeningForVideo)
                             toTarget: videoDepacketiser
                           withObject: nil];
}

- (void) viewWillDisappear:(BOOL)animated
{
    NSLog(@"VideoViewController exiting");
    [videoDepacketiser closeSocket];
}


#pragma mark -
#pragma mark OrientationUpdateResponderDelegate methods

// Helper method run when either changes
- (void) localOrRemoteOrientationDidChange
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

- (void) remoteOrientationDidChange:(UIDeviceOrientation)newOrientation
{
    currentRemoteOrientation = newOrientation;
    if (!isLocked) [self localOrRemoteOrientationDidChange];
}

- (void) localOrientationDidChange:(UIDeviceOrientation)newOrientation
{
    currentLocalOrientation = newOrientation;
    if (!isLocked) [self localOrRemoteOrientationDidChange]; 
}

- (void) lockOrientationResponse
{
    isLocked = YES;
}

- (void) unlockOrientationResponse
{
    isLocked = NO;
    [self localOrRemoteOrientationDidChange];
}


@end
