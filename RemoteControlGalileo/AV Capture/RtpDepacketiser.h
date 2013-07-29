#import <UIKit/UIKit.h>

@protocol RtpDepacketiserDelegate

- (void)processEncodedData:(NSData*)data;

@end

@interface RtpDepacketiser : NSObject
{
    u_short port;
    unsigned int rxSocket;
    unsigned int payloadHeaderLength;
}

@property(nonatomic, weak) id delegate;

// should we care about payload type?
- (id)initWithPort:(u_short)port payloadDescriptorLength:(unsigned int)payloadDescriptorLength;

- (void)openSocket;
- (void)startListening;
- (void)closeSocket;
- (BOOL)hasKeyframes;
- (BOOL)isKeyframe:(char *)payloadDescriptor;

// override this for subclasses
- (void)insertPacketIntoFrame:(char*)payload payloadDescriptor:(char*)payloadDescriptor 
                payloadLength:(unsigned int)payloadLength markerSet:(Boolean)marker;

@end
