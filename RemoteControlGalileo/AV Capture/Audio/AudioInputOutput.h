#import <UIKit/UIKit.h>
#import "GalileoCommon.h"

@protocol AudioInputDelegate

@required
- (void)didReceiveAudioBuffer:(void*)audioBuffer length:(size_t)length;

@end

@interface AudioInputOutput : NSObject <AudioConfigResponderDelegate>

- (void)addNotifier:(id<AudioInputDelegate>)notifier;
- (void)removeNotifier:(id<AudioInputDelegate>)notifier;

@end
