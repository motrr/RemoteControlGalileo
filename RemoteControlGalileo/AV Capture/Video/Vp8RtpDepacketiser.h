#import <UIKit/UIKit.h>
#import "RtpDepacketiser.h"

@interface Vp8RtpDepacketiser : RtpDepacketiser
{
}

- (id)initWithPort:(u_short)port;
- (BOOL)hasKeyframes;
- (BOOL)isKeyframe:(char *)payloadDescriptor;

//
- (void)insertPacketIntoFrame:(char*)payload payloadDescriptor:(char*)payloadDescriptor 
                payloadLength:(unsigned int)payloadLength markerSet:(Boolean)marker;

@end
