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
    labelRecordStatus = nil;
    [timer invalidate];
    timer = nil;
    NSLog(@"VideoViewController exiting");
}

- (void)loadView
{
    // Create the view which will show the received video
    self.wantsFullScreenLayout = YES;
    self.view = [[VideoView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];

    //[self.view.layer setMagnificationFilter:kCAFilterTrilinear];
    [self.view setBackgroundColor:[UIColor blackColor]];

    //
    labelRecordStatus = [[UILabel alloc] init];
    labelRecordStatus.backgroundColor = [UIColor clearColor];
    labelRecordStatus.textColor = [UIColor whiteColor];
    labelRecordStatus.shadowColor = [UIColor blackColor];
    labelRecordStatus.shadowOffset = CGSizeMake(1, 1);
    labelRecordStatus.userInteractionEnabled = NO;
    labelRecordStatus.transform = CGAffineTransformMakeRotation(M_PI_2);
    [self.view addSubview:labelRecordStatus];

    UITapGestureRecognizer *doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap:)];
    doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:doubleTapGestureRecognizer];
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

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

#pragma mark -
#pragma mark Workflow

- (void)flashStatusText:(NSString *)text
{
    //
    labelRecordStatus.text = text;
    [labelRecordStatus sizeToFit];
    labelRecordStatus.center = CGPointMake(self.view.bounds.size.width - labelRecordStatus.frame.size.width * 0.5, labelRecordStatus.frame.size.height * 0.5);
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
        BOOL val =[_mediaOutput stopRecord];
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
