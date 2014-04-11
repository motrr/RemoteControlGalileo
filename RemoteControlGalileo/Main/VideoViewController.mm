//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoViewController.h"
#import "VideoView.h"
#import "VideoInputOutput.h"
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

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDeviceOrientationChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onOSDVideoTextUpdate:) name:NOTIFICATION_VIDEO_RTCP_DATA_UPDATE object:nil];
        //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onOSDAudioTextUpdate:) name:NOTIFICATION_AUDIO_RTCP_DATA_UPDATE object:nil];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    labelRecordStatus = nil;
    labelRTCPStatus = nil;
    [timer invalidate];
    timer = nil;
    NSLog(@"VideoViewController exiting");
}

- (void)loadView
{
    // Create the view which will show the received video
    self.wantsFullScreenLayout = YES;
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    videoView = [[VideoView alloc] initWithFrame:self.view.bounds];
    videoView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    videoView.layer.magnificationFilter = kCAFilterTrilinear;
    [self.view addSubview:videoView];

    self.view.backgroundColor = [UIColor blackColor];
    videoView.backgroundColor = [UIColor blackColor];

    //
    labelRecordStatus = [[UILabel alloc] init];
    labelRecordStatus.backgroundColor = [UIColor clearColor];
    labelRecordStatus.textColor = [UIColor whiteColor];
    labelRecordStatus.shadowColor = [UIColor blackColor];
    labelRecordStatus.shadowOffset = CGSizeMake(1, 1);
    labelRecordStatus.userInteractionEnabled = NO;
    [self.view addSubview:labelRecordStatus];

    //
    labelRTCPStatus = [[UILabel alloc] init];
    labelRTCPStatus.backgroundColor = [UIColor clearColor];
    labelRTCPStatus.textColor = [UIColor whiteColor];
    labelRTCPStatus.shadowColor = [UIColor blackColor];
    labelRTCPStatus.shadowOffset = CGSizeMake(1, 1);
    labelRTCPStatus.userInteractionEnabled = NO;
    labelRTCPStatus.hidden = NO;
    labelRTCPStatus.numberOfLines = 0;
    [self.view addSubview:labelRTCPStatus];

    [self adjustLabelsTransform];
    [self adjustLabelsPosition];

    UITapGestureRecognizer *doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap:)];
    doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:doubleTapGestureRecognizer];
}

- (VideoView *)videoView
{
    if (!self.isViewLoaded)
        [self loadView];
    
    return videoView;
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

#pragma mark -
#pragma mark Workflow

- (void)onOSDVideoTextUpdate:(NSNotification *)notification
{
    id object = notification.object;
    if ([object isKindOfClass:[NSString class]]) @autoreleasepool {
        osdVideoDescription = object;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateOSD];
    });
}

- (void)onOSDAudioTextUpdate:(NSNotification *)notification
{
    id object = notification.object;
    if ([object isKindOfClass:[NSString class]]) @autoreleasepool {
        osdAudioDescription = object;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateOSD];
    });
}

- (void)updateOSD
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *osdText = [NSString stringWithFormat:@"%@\n%@", osdVideoDescription ? osdVideoDescription : @"", osdAudioDescription ? osdAudioDescription : @""];
        labelRTCPStatus.text = osdText;
        [self adjustLabelsPosition];
    });
}

- (void)flashStatusText:(NSString *)text
{
    //
    labelRecordStatus.text = text;
    [labelRecordStatus sizeToFit];
    [self adjustLabelsPosition];

    //
    labelRecordStatus.alpha = 1.f;

    [UIView animateWithDuration:2.f animations:^{
        labelRecordStatus.alpha = 0.5;
    } completion:^(BOOL finished) {
        labelRecordStatus.alpha = 0.f;
    }];
}

- (void)onDoubleTap:(UITapGestureRecognizer*)gestureRecognizer
{
    [networkControllerDelegate sendSetRecording:!isRecording isResponse:false];
}

- (void)startOSDTimer
{
    if (timer)
    {
        [timer invalidate];
    }

    timer = [NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(onTimerTick:) userInfo:nil repeats:YES];
    timerStartTime = [NSDate date];
    calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    [timer fire];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (void)stopOSDTimer
{
    [timer invalidate];
    timer = nil;
    timerStartTime = nil;
    calendar = nil;
}

- (void)onTimerTick:(NSTimer *)timer
{
    NSDate *currentTime = [NSDate date];
    showTimerColon = !showTimerColon;

    NSDateComponents *components = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond
                                               fromDate:timerStartTime
                                                 toDate:currentTime
                                                options:0];
    NSString *colon = showTimerColon ? @":" : @" ";
    NSString *secondsFormat = components.second > 9 ? @"%i" : @"0%i";

    NSString *timerText = [NSString stringWithFormat:@"Recording %i%@%@", components.minute, colon, [NSString stringWithFormat:secondsFormat,components.second]];
    [self flashStatusText:timerText];
}

- (void)adjustLabelsTransform
{
    CGAffineTransform transform;

    switch ([UIDevice currentDevice].orientation)
    {
        case UIDeviceOrientationLandscapeLeft:
            transform = CGAffineTransformMakeRotation(M_PI_2);
            break;

        case UIDeviceOrientationLandscapeRight:
            transform = CGAffineTransformMakeRotation(-M_PI_2);
            break;

        case UIDeviceOrientationPortraitUpsideDown:
            transform = CGAffineTransformMakeRotation(M_PI);
            break;

        case UIDeviceOrientationPortrait:
            transform = CGAffineTransformIdentity;
            break;

        default: return;//skip any update
            
    }

    labelRecordStatus.transform = transform;
    labelRTCPStatus.transform = transform;
}

- (void)adjustLabelsPosition
{
    CGPoint centerRecordStatus;
    CGPoint centerRTCPStatus;
    [labelRTCPStatus sizeToFit];

    switch ([UIDevice currentDevice].orientation)
    {
        case UIDeviceOrientationLandscapeLeft:
        {
            centerRecordStatus = CGPointMake(self.view.bounds.size.width - labelRecordStatus.frame.size.width * 0.5, labelRecordStatus.frame.size.height * 0.5);
            centerRTCPStatus = CGPointMake(self.view.bounds.size.width - labelRTCPStatus.frame.size.width * 0.5, self.view.bounds.size.height - labelRTCPStatus.frame.size.height * 0.5);
            break;
        }

        case UIDeviceOrientationLandscapeRight:
        {
            centerRecordStatus = CGPointMake(labelRecordStatus.frame.size.width * 0.5, self.view.bounds.size.height - labelRecordStatus.frame.size.height * 0.5);
            centerRTCPStatus = CGPointMake(labelRTCPStatus.frame.size.width * 0.5, labelRTCPStatus.frame.size.height * 0.5);
            break;
        }

        case UIDeviceOrientationPortraitUpsideDown:
        {
            centerRecordStatus = CGPointMake(self.view.bounds.size.width - labelRecordStatus.frame.size.width * 0.5, self.view.bounds.size.height - labelRecordStatus.frame.size.height * 0.5);
            centerRTCPStatus = CGPointMake(self.view.bounds.size.width - labelRTCPStatus.frame.size.width * 0.5, labelRTCPStatus.frame.size.height * 0.5);
            break;
        }

        case UIDeviceOrientationPortrait:
        {
            centerRecordStatus = CGPointMake(labelRecordStatus.frame.size.width * 0.5, labelRecordStatus.frame.size.height * 0.5);
            centerRTCPStatus = CGPointMake(labelRTCPStatus.frame.size.width * 0.5, self.view.bounds.size.height - labelRTCPStatus.frame.size.height * 0.5);
            break;
        }

        default: return;//skip any update

    }

    labelRecordStatus.center = centerRecordStatus;
    labelRTCPStatus.center = centerRTCPStatus;
}

- (void)onDeviceOrientationChange:(NSNotification *)notification
{
    [self adjustLabelsTransform];
    [self adjustLabelsPosition];
}

#pragma mark - RecordStatusResponderDelegate

- (void)remoteRecordStarted:(bool)value
{
    //
    isRecording = value;
    [self flashStatusText:[NSString stringWithFormat:@"Remote record %@", value ? @"STARTED" : @"STOPPED"]];

    if (value)
    {
        [self startOSDTimer];
    }
    else
    {
        [self stopOSDTimer];
    }
}

- (void)startRecord:(bool)value
{
    //
    isRecording = value;
    if (!value)
    {
        BOOL val = [_mediaOutput stopRecord];
        NSLog(@"Stop %@", val ? @"OK" : @"FAIL");

        [self flashStatusText:@"Recording stopped"];
        [networkControllerDelegate sendSetRecording:isRecording isResponse:true];
    }
    else
    {
        //
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
        NSString *stringFromDate = [formatter stringFromDate:[NSDate date]];

        //
        NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSString *filePath = [documentsDirectory stringByAppendingPathComponent:[stringFromDate stringByAppendingPathExtension:@"m4v"]];

        //
        int width = [UIScreen mainScreen].bounds.size.height; // landscape
        int height = [UIScreen mainScreen].bounds.size.width; // landscape
        NSLog(@"Start with file %@", stringFromDate);

        BOOL val = [_mediaOutput setupWithFilePath:filePath width:width height:height hasAudio:true sampleRate:8000 /*mStreamDescription.mSampleRate*/ channels:1/*mStreamDescription.mChannelsPerFrame*/ bitsPerChannel:16];
        NSLog(@"Setup %@", val ? @"OK" : @"FAIL");
        val = [_mediaOutput startRecord];
        NSLog(@"Start record %@", val ? @"OK" : @"FAIL");

        [self flashStatusText:@"Recording started"];
        [networkControllerDelegate sendSetRecording:isRecording isResponse:true];

    }
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
    [self logOrientation:currentLocalOrientation message:@"local"];
    [self logOrientation:currentRemoteOrientation message:@"remote"];
    
    if (!isRotated180)
    {
        // Only do anything if 180 disparity between local and remote
        if ((    currentLocalOrientation == UIDeviceOrientationLandscapeLeft
             && currentRemoteOrientation == UIDeviceOrientationLandscapeLeft)
            ||
            (    currentLocalOrientation == UIDeviceOrientationLandscapeRight
             && currentRemoteOrientation == UIDeviceOrientationLandscapeRight)
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
                                 videoView.transform = CGAffineTransformMakeRotation(M_PI);
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
                                 videoView.transform = CGAffineTransformMakeRotation(-M_PI);
                             }
             ];
        }
    }
    else if(isRotated180)
    {
        // We dont want any jumping here, so lets just return back only when needed
        if ((    currentLocalOrientation == UIDeviceOrientationLandscapeLeft
             && currentRemoteOrientation == UIDeviceOrientationLandscapeRight)
            ||
            (    currentLocalOrientation == UIDeviceOrientationLandscapeRight
             && currentRemoteOrientation == UIDeviceOrientationLandscapeLeft)
            ||
            (    currentLocalOrientation == UIDeviceOrientationPortrait
             && currentRemoteOrientation == UIDeviceOrientationPortrait)
            ||
            (    currentLocalOrientation == UIDeviceOrientationPortraitUpsideDown
             && currentRemoteOrientation == UIDeviceOrientationPortraitUpsideDown))
        {
            isRotated180 = NO;
            [UIView animateWithDuration: ROTATION_ANIMATION_DURATION
                             animations:^ {
                                 videoView.transform = CGAffineTransformIdentity;
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
