#import <Foundation/Foundation.h>
#import "CameraInput.h"
#import "AudioInputOutput.h"

enum MediaState
{
    MS_Null = 0,
    MS_Loading, // prepare for play
    MS_Loaded,
    MS_Running,
    MS_Finalizing,
    MS_Finished,
    MS_Error, // can't load/play
};


@interface MediaOutput : NSObject <CameraInputDelegate, AudioInputDelegate>

@property (nonatomic, readonly) MediaState state;

- (BOOL)setupWithFilePath:(NSString*)filePath width:(int)width height:(int)height hasAudio:(bool)hasAudio sampleRate:(int)sampleRate channels:(int)channels bitsPerChannel:(UInt32)bitsPerChannel;

- (BOOL)startRecord;
- (BOOL)stopRecord;

@end
