//  Created by Chris Harding on 22/12/2011.
//  Copyright (c) 2011 Swift Navigation. All rights reserved.
//

#import "GKNetController.h"

#import <ifaddrs.h>
#import <arpa/inet.h>

#import "IpAddress.h"

// Special 8bit value used to signify no change
#define NO_CHANGE INT8_MIN

// Packets for ping and pong
typedef struct {
    UInt16 index;
} PingPacket;

// Packet to signal recipient address for broadcasting video
typedef struct {
    UInt8 ip1;
    UInt8 ip2;
    UInt8 ip3;
    UInt8 ip4;
} IpAddressPacket;

// Packet to send on orientation changed
typedef struct {
    UIDeviceOrientation orientation;
} OrientationPacket;

// Packet to send Galileo control commands
typedef struct {
    int8_t pan;
    int8_t tilt;
    bool momentum;
} GalileoControlPacket;

// Packet to send Galileo zoom commands
typedef struct {
    float_t scale;
} GalileoZoomPacket;



@implementation GKNetController

@synthesize connectionStateResponder;
@synthesize videoConfigResponder;
@synthesize audioConfigResponder;
@synthesize orientationUpdateResponder;
@synthesize galileoControlResponder;

#pragma mark -
#pragma mark NSObject initialisation

- (id) initWithManager:(GKSessionManager *)aManager
{
    if (self = [super init]) {
        manager = aManager;
        manager.gameDelegate = self;
        srandomdev();
        
        // Setup for ping/pong
        pingCounter = 0;
        pingTable = [NSMutableDictionary dictionaryWithCapacity:50];
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"GKNetController exiting");
}


#pragma mark -
#pragma mark SessionManagerGameDelegate Methods

- (void) willStart:(GKSessionManager *)session
{
    // Delegate to connection state responder
    [self.connectionStateResponder connectionIsNowAlive];
}

- (void) willDisconnect:(GKSessionManager *)session
{
    // Delegate to connection state responder
    [self.connectionStateResponder connectionIsDead];
}


// Helper methods for parsing packets
- (void) parseIpAddressPacket: (NSData*) data
{
    IpAddressPacket incoming;
    
    if ([data length] == sizeof(IpAddressPacket)) {
        [data getBytes:&incoming length:sizeof(IpAddressPacket)];
        
        NSLog(@"IP address packet recieved");
        
        // Get IP from packet as a string
        NSString* ipAddressString = [NSString stringWithFormat:@"%d.%d.%d.%d",
                                        incoming.ip1,
                                        incoming.ip2,
                                        incoming.ip3,
                                        incoming.ip4];
        [videoConfigResponder ipAddressRecieved: ipAddressString];
        [audioConfigResponder ipAddressRecieved: ipAddressString];
        
    }
}
- (void) parseOrientationChangedPacket: (NSData*) data
{
    OrientationPacket incoming;
    
    if ([data length] == sizeof(OrientationPacket)) {
        [data getBytes:&incoming length:sizeof(OrientationPacket)];
        
        [orientationUpdateResponder remoteOrientationDidChange: incoming.orientation];
    }
}
- (void) parseControlPacket: (NSData*) data
{
    GalileoControlPacket incoming;
    
    if ([data length] == sizeof(GalileoControlPacket)) {
        [data getBytes:&incoming length:sizeof(GalileoControlPacket)];
        
        NSNumber *panAmount, *tiltAmount;
        Boolean ignorePan = NO;
        Boolean ignoreTilt = NO;
        
        // Look out for no change values
        if (incoming.pan == NO_CHANGE)  ignorePan = YES;
        else                            panAmount  = [NSNumber numberWithChar: incoming.pan];
        if (incoming.tilt == NO_CHANGE) ignoreTilt = YES;
        else                            tiltAmount = [NSNumber numberWithChar: incoming.tilt];

        [galileoControlResponder galileoControlCommandRecievedWithPan: panAmount  ignore: ignorePan
                                                                 tilt: tiltAmount ignore: ignoreTilt
                                                             momentum:incoming.momentum];        
    }
}

- (void) parseZoomPacket: (NSData*) data
{
    GalileoZoomPacket incoming;
    
    if ([data length] == sizeof(GalileoZoomPacket)) {
        
        NSLog(@"Zoom update packet recieved");
        
        [data getBytes:&incoming length:sizeof(GalileoZoomPacket)];
        
        NSNumber *scale = [NSNumber numberWithFloat:incoming.scale];  
        [videoConfigResponder zoomLevelUpdateRecieved:scale];
        
    }
}

- (void) parsePingPacket: (NSData*) data
{
    PingPacket incoming;
    if ([data length] == sizeof(PingPacket)) {
        [data getBytes:&incoming length:sizeof(PingPacket)];
        
        // Respond by returning a pong with the same index
        [self sendPong: incoming.index];
    }
}
- (void) parsePongPacket: (NSData*) data
{
    PingPacket incoming;
    if ([data length] == sizeof(PingPacket)) {
        [data getBytes:&incoming length:sizeof(PingPacket)];
        
        // Log the time of reciept and lookup the time when sent
        NSDate* timeWhenRecieved = [[NSDate alloc] init];
        NSDate* timeWhenSent = [pingTable objectForKey: [NSNumber numberWithInt:incoming.index]];
        
        // Print round trip time
        NSLog( @"Ping successful: time=%f ms", [timeWhenRecieved timeIntervalSinceDate: timeWhenSent] * 1000 );
    }
}


// The GKSession got a packet so parse it and update state.
- (void) session:(GKSessionManager *)session didReceivePacket:(NSData *)data ofType:(PacketType)packetType
{
    switch (packetType) {

        case PacketTypeIpAddress:
            [self parseIpAddressPacket:data];
            break;
        case PacketTypeOrientationChanged:
            [self parseOrientationChangedPacket:data];
            break;
        case PacketTypeControl:
            [self parseControlPacket:data];
            break;
        case PacketTypeZoom:
            [self parseZoomPacket:data];
            break;
            break;
        case PacketTypePing:
            [self parsePingPacket:data];
            break;
        case PacketTypePong:
            [self parsePongPacket:data];
            break;

        default:
            break;
    }
    
}

#pragma mark -
#pragma mark NetworkControllerDelegate methods

// Helper method to determine local IP address
- (NSString *)deviceIPAdress {
    if (!already_got_ip_address) {
        FreeAddresses();
        GetIPAddresses();
    }
    NSString* deviceIp = [NSString stringWithFormat:@"%s", ip_names[1]];
    NSLog( @"Local device IP address is %@", deviceIp);
    return deviceIp;
}

// Send local IP address to use for broadcasting video
-(void) sendIpAddress
{
    NSLog( @"Going to send IP address packet");
    
    IpAddressPacket outgoing;
    
    // Create packet using local IP address
    NSArray* addressArray = [[self deviceIPAdress] componentsSeparatedByString:@"."];
    outgoing.ip1 = [((NSString*) [addressArray objectAtIndex:0]) intValue];
    outgoing.ip2 = [((NSString*) [addressArray objectAtIndex:1]) intValue];
    outgoing.ip3 = [((NSString*) [addressArray objectAtIndex:2]) intValue];
    outgoing.ip4 = [((NSString*) [addressArray objectAtIndex:3]) intValue];
    
    NSData *packet = [[NSData alloc] initWithBytes:&outgoing length:sizeof(IpAddressPacket)];
    [manager sendPacket:packet ofType:PacketTypeIpAddress reliable:YES];
}

// Send an orientation changed event to ensure diaplay is correct way up
- (void) sendOrientationUpdate: (UIDeviceOrientation) orientation
{
    NSLog( @"Going to send orientation update packet");
    
    OrientationPacket outgoing;
    
    outgoing.orientation = orientation;
    
    NSData* packet = [[NSData alloc] initWithBytes:&outgoing length:sizeof(OrientationPacket)];
    [manager sendPacket:packet ofType:PacketTypeOrientationChanged reliable:YES];
    
}

// Send a command to control remote Galileo
- (void) sendGalileoControlWithPan: (NSNumber*) panAmount ignore: (Boolean) ignorePan
                             tilt : (NSNumber*) tiltAmount ignore: (Boolean) ignoreTilt
                          momentum:(bool) momentum
{
    //NSLog( @"Going to send Galileo control packet");
    GalileoControlPacket outgoing;
    
    // We use NO_CHANGE to signify no change to velocity
    if (!ignorePan)
        outgoing.pan = panAmount.intValue;
    else
        outgoing.pan = NO_CHANGE;
    
    // We use NO_CHANGE to signify no change to velocity
    if (!ignoreTilt)
        outgoing.tilt = tiltAmount.intValue;
    else
        outgoing.tilt = NO_CHANGE;
    
    NSData* packet = [[NSData alloc] initWithBytes: &outgoing length:sizeof(GalileoControlPacket)];
    [manager sendPacket:packet ofType:PacketTypeControl reliable:YES];
    
}

- (void) sendZoomFactor:(NSNumber *)scale
{
    //NSLog( @"Going to send Galileo zoom packet");
    GalileoZoomPacket outgoing;
    
    outgoing.scale = [scale floatValue];
    
    NSData* packet = [[NSData alloc] initWithBytes: &outgoing length:sizeof(GalileoZoomPacket)];
    [manager sendPacket:packet ofType:PacketTypeZoom reliable:YES];
}


// Send ping/pong packets for latency guaging
- (void) sendPing
{
    PingPacket outgoing;
    outgoing.index = pingCounter++;
    NSData *packet = [[NSData alloc] initWithBytes:&outgoing length:sizeof(PingPacket)];
    
    // Log the time and send the packet
    NSDate* timeWhenSent = [[NSDate alloc] init];
    [manager sendPacket:packet ofType:PacketTypePing reliable:YES];
    
    // Store time in dictionary
    [pingTable setObject: timeWhenSent forKey: [NSNumber numberWithInt:outgoing.index] ];
    
}
- (void) sendPong: (UInt16) recievedPingIndex
{
    PingPacket outgoing;
    outgoing.index = recievedPingIndex;
    NSData *packet = [[NSData alloc] initWithBytes:&outgoing length:sizeof(PingPacket)];
    [manager sendPacket:packet ofType:PacketTypePong reliable:YES];
}


@end
