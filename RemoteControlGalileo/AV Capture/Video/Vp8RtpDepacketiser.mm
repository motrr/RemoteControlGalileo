#import "Vp8RtpDepacketiser.h"
#import "VideoTxRxCommon.h"

@implementation Vp8RtpDepacketiser

- (id)initWithPort:(u_short)inputPort
{
    self = [super initWithPort:inputPort payloadDescriptorLength:sizeof(Vp8PayloadDescriptorStruct)];
    
    return self;
}

- (void)dealloc
{
}

- (BOOL)hasKeyframes
{
    return YES;
}

- (BOOL)isKeyframe:(char *)payloadDescriptor
{
    Vp8PayloadDescriptorStruct *descriptor = (Vp8PayloadDescriptorStruct *)payloadDescriptor;
    
    return (descriptor->nonReferenceFrame && descriptor->partiotionStart);
}

- (void)insertPacketIntoFrame:(char*)payload payloadDescriptor:(char*)payloadDescriptor 
                payloadLength:(unsigned int)payloadLength markerSet:(Boolean)marker
{
    //Vp8PayloadDescriptorStruct *vp8_payload_descriptor = (Vp8PayloadDescriptorStruct*)payloadDescriptor;
        
    //
        
    [super insertPacketIntoFrame:payload payloadDescriptor:payloadDescriptor payloadLength:payloadLength markerSet:marker];
}

@end
