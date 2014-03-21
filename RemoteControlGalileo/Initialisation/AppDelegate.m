//
//  AppDelegate.m
//  RemoteControlGalileo
//
//  Created by Chris Harding on 14/06/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "AppDelegate.h"
#import "RootViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

// Colour of the iDevice, blackColor or whiteColor
#define DEVICE_COLOUR blackColor

// custom navigation controller with portrait orientation only
@interface MyNavigationController : UINavigationController
@end

@implementation MyNavigationController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

@end

@implementation AppDelegate

@synthesize window;
@synthesize viewController;
@synthesize navigationController;

#pragma mark -
#pragma mark Application lifecycle

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    // Get bounding frames
    CGRect screenBounds = [[UIScreen mainScreen] applicationFrame];
    CGRect visibleScreenBounds = CGRectMake(0, 0,
                                            CGRectGetWidth(screenBounds),
                                            CGRectGetHeight(screenBounds)
                                            );
    
    // Create root view controller
    self.viewController = [[RootViewController alloc] init];
    
    // Initialise a navigation controller using the controller as the root
    self.navigationController = [[MyNavigationController alloc] initWithRootViewController: self.viewController];
    [self.navigationController setNavigationBarHidden:NO];
    self.navigationController.navigationBar.translucent = NO;
    
    // Initialise the window, matching the background to the device's colour since it is visible when rotating
    self.window = [[UIWindow alloc] initWithFrame:visibleScreenBounds];
    [window setBackgroundColor:[UIColor DEVICE_COLOUR]];
    
    // Make status bar content light on iOS 7
    double iOSVersion = [[[UIDevice currentDevice] systemVersion] doubleValue];
    if(iOSVersion >= 7.0)
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
    
    // Add the navigation controller's view to window and make window visible
    if(iOSVersion < 4.0)
        [self.window addSubview:self.navigationController.view];
    else
        self.window.rootViewController = self.navigationController;
    
    [self.window makeKeyAndVisible];

    // request permissions after ui appear
    dispatch_async(dispatch_get_main_queue(), ^{
        [self requestPermissions];
    });
}

- (void)requestPermissions
{
    // camera
    if([[AVCaptureDevice class] respondsToSelector:@selector(requestAccessForMediaType:completionHandler:)])
    {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {

            if (!granted)
                NSLog(@"User will not be able to use the camera!");
        }];
    }

    // microphone
    if([[AVCaptureDevice class] respondsToSelector:@selector(requestAccessForMediaType:completionHandler:)])
    {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {

            if (!granted)
                NSLog(@"User will not be able to use the microphone!");
        }];
    }

    // camera roll
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        // nothing
        } failureBlock:^(NSError *error) {
            NSLog(@"User will not be able to use the camera roll!");
    }];
    
}

@end
