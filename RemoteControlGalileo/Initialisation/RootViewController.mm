//
//  RootViewController.m
//  GalileoWifi
//
//  Created by Chris Harding on 10/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "RootViewController.h"
#import "GKSessionManager.h"
#import "GKLobbyViewController.h"
#import "RemoteControlGalileo.h"
#import "GKNetController.h"

@implementation RootViewController
{
    GKSessionManager *manager;
    GKLobbyViewController *lobby;
    GKNetController *netController;
    RemoteControlGalileo *rcGalileo;
}

#pragma mark -
#pragma mark - View lifecycle

- (void)loadView
{
    // Create the view which will contain the lobby view
    self.title = @"Galileo Peer List";
    self.wantsFullScreenLayout = YES;
    self.view = [[UIImageView alloc]
                 initWithFrame:[UIScreen mainScreen].applicationFrame];
    [self.view setUserInteractionEnabled:YES];

}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Create a GK session manager
    manager = [[GKSessionManager alloc] init];

    // Create a GK lobby view controller with the session
    lobby = [[GKLobbyViewController alloc] initWithSessionManager:manager connectionStateResponder:self];
    
    // Add lobby as subview
    lobby.view.frame = self.view.bounds;
    lobby.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview: lobby.view];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

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

#pragma mark -
#pragma mark ConnectionStateResponderDelegate methods

// Peer has been chosen, create Galileo object
- (void)peerSelected
{
    NSLog(@"Connection state changed - peerSelected");
    
    // Create a GameKit network controller for Galileo, using the session manager
    netController = [GKNetController alloc];
    netController.connectionStateResponder = self;
    netController = [netController initWithManager:manager];
    
    // Create a Galileo object with the network controller. This will set required delegates in the net controller
    rcGalileo = [[RemoteControlGalileo alloc] initWithNetworkController:netController];
    
}

// Connection is now live (send and recieve successful), perform some initialisation
- (void)connectionIsNowAlive
{
     NSLog(@"Connection state changed - connectionIsNowAlive");
    
    // Signal to the Galileo object that the connection is up and running
    [rcGalileo networkControllerIsReady];
    
    // Push video view controller on to navigation stack
    [self.navigationController pushViewController:(UIViewController*)rcGalileo.videoViewController animated:YES];
    
    // Hide status bar
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    
    // Turn screen saving off
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
}

// Disconnected for some reason, kill galileo object
- (void)connectionIsDead
{
     NSLog(@"Connection state changed - connectionIsDead");
    // Turn screen saving back on
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    
    // Show status bar
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
    
    // Pop video view controller from navigation stack
    [self.navigationController popViewControllerAnimated:YES];
    
    // Nil out Galileo and net controller so they can be released
    rcGalileo = nil;
    netController = nil;
    
    // Restart session manager
    [manager setupSession];
    
}

@end
