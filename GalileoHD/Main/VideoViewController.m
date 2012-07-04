//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoViewController.h"
#import  <QuartzCore/CALayer.h>
#import "VideoDecoder.h"
#import "VideoView.h"

#import <sys/socket.h>
#import <netinet/in.h>

#define ROTATION_ANIMATION_DURATION 0.5

@implementation VideoViewController

@synthesize networkControllerDelegate;


#pragma mark -
#pragma mark Initialisation and view life cycle

- (id) init
{
    if (self = [super init]) {
        
        videoDecoder = [[VideoDecoder alloc] init];
        
        port = AV_UDP_PORT;
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
    
}


- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    
    return NO;
}


- (void) viewWillAppear:(BOOL)animated
{
    // Create socket to listen out for video transmission
    [self openSocket];

    // Start listening in the background
    [NSThread detachNewThreadSelector: @selector(startListeningForVideo)
                             toTarget: self
                           withObject: nil];
}

- (void) viewWillDisappear:(BOOL)animated
{
    NSLog(@"VideoViewController exiting");
    close(videoRxSocket);
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


#pragma mark -
#pragma mark Video reception over UDP

// Start listening for tranmission on a UDP port
- (void) openSocket
{
    NSLog(@"Listening for video on port %u", port);
    
    // Declare variables
    struct sockaddr_in si_me;
    
    // Create a server socket
    if ((videoRxSocket=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP))==-1)
        NSLog(@"Failed to create video Rx socket.");
    
    // Create the address
    memset((char *) &si_me, 0, sizeof(si_me));
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(port);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    
    // Bind address to socket
    if ( bind(videoRxSocket, (struct sockaddr *) &si_me, sizeof(si_me)) == -1) {
        NSLog(@"Failed to bind video Rx socket to address.");
    }
    
}

- (void) startListeningForVideo
{
    struct sockaddr_in si_other;
    unsigned int slen=sizeof(si_other);
    char buffer[AV_UDP_BUFFER_LEN];
    int data_len;
    
    // Begin listening for data (JPEG video frames)
    for (;;) {
        
        // Otherwise, recieve and display frame
        @autoreleasepool {
            
            data_len = recvfrom(videoRxSocket,
                                (void *) buffer,
                                AV_UDP_BUFFER_LEN, 
                                0,
                                (struct sockaddr *) &si_other,
                                &slen);
            
            if (data_len < 0)
            {
                NSLog(@"Bad return value from server socket recvrom()." );
                [NSThread exit];
            }
            else {
                
                // Decode data buffer into pixel buffer
                NSData* data = [NSData dataWithBytesNoCopy:buffer length:data_len freeWhenDone:NO];
                CVPixelBufferRef pixelBuffer = [videoDecoder decodeFrameData:data];
                
                // Render the pixel buffer using OpenGL
                [self.view performSelectorOnMainThread:@selector(renderPixelBuffer:) withObject:(__bridge id)(pixelBuffer) waitUntilDone:YES];
                
            } 
            
        }
        
    }
    
    
}

void pixelBufferReleaseCallback(void *releaseRefCon, const void *baseAddress)
{
    // Alias to the entire buffer, including the JPEG framgment header
    char* old_frame = (char*)baseAddress;
    
    // Deallocate
    free(old_frame);
}


@end
