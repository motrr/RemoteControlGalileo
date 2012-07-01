//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoViewController.h"
#import  <QuartzCore/CALayer.h>

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
        
        frame = calloc(AV_UDP_BUFFER_LEN, sizeof(char));
        current_header = (JPEGFragmentHeaderStruct*) frame;
        current_header->frame_number = 0;
        current_header->total_length = 0;
        port = AV_UDP_PORT;
        isLocked = NO;
        
    }
    return self;
    
}

- (void) loadView
{
    // Create the view which will show the received video
    self.wantsFullScreenLayout = YES;
    self.view = [[UIImageView alloc]
                 initWithFrame:[UIScreen mainScreen].applicationFrame];
    [self.view.layer setMagnificationFilter:kCAFilterTrilinear];
    [self.view setBackgroundColor:[UIColor blackColor]];
    
    /*
    // Add button for recording video
    recordButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    recordButton.frame = CGRectMake(0,0,200,50);
    recordButton.transform = CGAffineTransformMakeRotation(-M_PI/2);
    recordButton.center = self.view.center;
    recordButton.frame = CGRectApplyAffineTransform(recordButton.frame, CGAffineTransformMakeTranslation(110, 0));
    
    [recordButton setTitle:@"Start recording" forState:UIControlStateNormal];
    [recordButton setTitleColor: [UIColor blackColor] forState: UIControlStateNormal];
    [self.view addSubview:recordButton];
    [recordButton addTarget:self action:@selector(recordButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    isRecording = NO;
     */
    
}

- (void) recordButtonPressed
{
    if (isRecording) {        
        
        [networkControllerDelegate sendRecordCommand:NO];
        NSLog(@"Recording stopped");
        [recordButton setTitle:@"Start recording" forState:UIControlStateNormal];
        
    }
    else {
        [networkControllerDelegate sendRecordCommand:YES];
        NSLog(@"Recording started");
        [recordButton setTitle:@"Finish recording" forState:UIControlStateNormal];
        
        
    }
    isRecording = !isRecording;
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
    free(frame);
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
                
                incoming_header = (JPEGFragmentHeaderStruct*) buffer;
                //NSLog(@"frame num %u", incoming_header->frame_number);
                
                // Ignore old fragments
                if (current_header->frame_number <= incoming_header->frame_number) {
                    
                    //NSLog(@"Fragment arrived");
                    
                    // If the fragment is from a later frame, display current frame then copy in new header and start bytes
                    if (current_header->frame_number < incoming_header->frame_number) {
                        
                        // Display
                        //NSLog(@"Recieved frame %u", current_header->frame_number);
                        /*
                         printf("\n");
                         for (int j = sizeof(JPEGFragmentHeaderStruct); j<current_header->total_length+sizeof(JPEGFragmentHeaderStruct); j++) {
                         printf( "%c", frame[j] );
                         }
                         printf("\n");
                         */
                        
                        // Decompress image and display on the view controller's view
                        imageData = [NSData dataWithBytes:(frame+sizeof(JPEGFragmentHeaderStruct)) length:current_header->total_length];
                        [self.view performSelectorOnMainThread:@selector(setImage:) withObject:[UIImage imageWithData:imageData] waitUntilDone:YES];
                        
                        
                        // Copy new header and start bytes
                        memcpy(frame, buffer, sizeof(JPEGFragmentHeaderStruct) + JPEG_HEADER_LENGTH);
                        
                    }
                    
                    // Insert new fragment into frame at the correct position
                    unsigned int off = incoming_header->fragment_offset;
                    memcpy((frame+off), (buffer+((sizeof(JPEGFragmentHeaderStruct)+JPEG_HEADER_LENGTH))), incoming_header->fragment_length);
                    
                    
                    
                }
                
                else NSLog(@"Warning - old fragment arrived");
            } 
            
        }
        
    }
    
    
}



@end
