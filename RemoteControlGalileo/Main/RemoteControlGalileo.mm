//  Created by Chris Harding on 31/12/2011.
//  Copyright (c) 2011 Swift Navigation. All rights reserved.
//

#import "RemoteControlGalileo.h"
#import "GKSessionManager.h"

#import "GalileoCommon.h"
#import "GKNetController.h"
#import "VideoInputOutput.h"
#import "AudioInputOutput.h"
#import "VideoViewController.h"
#import "UserInputHandler.h"
#import "DockConnectorController.h"
#import "VideoView.h"

@implementation RemoteControlGalileo

@synthesize videoViewController;

- (id)initWithNetworkController:(id<NetworkControllerDelegate>)initNetworkController
{
    self = [super init];
    if(self)
    {
        // Store the networking module, this will negotiate networks comms.
        networkController = initNetworkController;
        
        // Create subcomponents
        videoInputOutput    = [[VideoInputOutput alloc] init];
        audioInputOutput    = [[AudioInputOutput alloc] init];
        videoViewController = [[VideoViewController alloc] init];
        userInputHandler    = [[UserInputHandler alloc] init];
        serialController    = [[DockConnectorController alloc] init];
        
        // Set delegates for responding to recieved packets
        [networkController setVideoConfigResponder:videoInputOutput];
        [networkController setAudioConfigResponder:audioInputOutput];
        [networkController setOrientationUpdateResponder:videoViewController];
        [networkController setGalileoControlResponder:serialController];
        
        // Delegate packet sending to the network module
        [videoViewController setNetworkControllerDelegate:networkController];
        [userInputHandler    setNetworkControllerDelegate:networkController];
        
        // User input handler delegates orientation change handling to video view controller
        [userInputHandler setOrientationUpdateResponder:videoViewController];
        
        // User input handler needs a view to get touch responses from
        [userInputHandler setViewForGestureInput:videoViewController.view];
        
        VideoView *videoView = (VideoView*)videoViewController.view;
        videoInputOutput.delegate = videoView;
        
        // Start pinging
        //timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:networkModule selector:@selector(sendPing) userInfo:nil repeats:YES];
    }
    
    return self;
}

- (void)networkControllerIsReady
{
    // Set initial orientation locally for the video view controller
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    [videoViewController localOrientationDidChange:orientation];
    
    // Also send to remote
    [networkController sendOrientationUpdate:orientation];
    
    // Send IP address for video broadcasting
    [networkController sendIpAddress];
}

- (void)dealloc
{
    NSLog(@"Galileo exiting");
}

@end
