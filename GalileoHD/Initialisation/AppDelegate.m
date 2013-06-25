//
//  AppDelegate.m
//  GalileoHD
//
//  Created by Chris Harding on 14/06/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "AppDelegate.h"
#import "RootViewController.h"

// Colour of the iDevice, blackColor or whiteColor
#define DEVICE_COLOUR blackColor

@implementation AppDelegate

@synthesize window;
@synthesize viewController;
@synthesize navigationController;

#pragma mark -
#pragma mark Application lifecycle

- (void)applicationDidFinishLaunching:(UIApplication *)application {    
    
    // Get bounding frames
    CGRect screenBounds = [[UIScreen mainScreen] applicationFrame];
    CGRect visibleScreenBounds = CGRectMake(0, 0,
                                            CGRectGetWidth(screenBounds),
                                            CGRectGetHeight(screenBounds)
                                            );
    
    // Create root view controller
    self.viewController = [[RootViewController alloc] init];
    
    // Initialise a navigation controller using the controller as the root
    self.navigationController = [[UINavigationController alloc] initWithRootViewController: self.viewController];
    [self.navigationController setNavigationBarHidden:YES];
    
    // Initialise the window, matching the background to the device's colour since it is visible when rotating
    self.window = [[UIWindow alloc] initWithFrame: visibleScreenBounds];
    [window setBackgroundColor: [UIColor DEVICE_COLOUR]];
    
    // Add the navigation controller's view to window and make window visible
    [self.window addSubview:self.navigationController.view];
    [self.window makeKeyAndVisible];
    
}


@end
