#import "RtpDepacketiser.h"
#import "VideoTxRxCommon.h"

#import <sys/socket.h>
#import <netinet/in.h>

#define PACKET_BUFFER_SIZE 10
#define FRAME_BUFFER_SIZE 20

@interface RtpDepacketiser ()
{
    // Dispatch queue for decoding
    dispatch_queue_t decodingQueue;
    
    char *currentFrame;
    
    // We keep a buffer of frames, so decoding and depacketising can take place concurrently
    char *frameBuffer[FRAME_BUFFER_SIZE];
    unsigned int currentFrameIndex;
    
    // We keep a buffer of packets to deal with out of order packets
    char *packetPuffer[PACKET_BUFFER_SIZE];
    unsigned int nextPacketIndex;
    
    unsigned int incomingTimestamp;
    unsigned int nextSequenceNum;
    unsigned int incomingSequenceNum;
    
    unsigned int byteInFrameSoFar;
    
    Boolean skipThisFrame;
}

@end

@implementation RtpDepacketiser

- (id)initWithPort:(u_short)inputPort payloadDescriptorLength:(unsigned int)payloadDescriptorLength
{
    if(self = [super init])
    {
        payloadHeaderLength = sizeof(RtpPacketHeaderStruct) + payloadDescriptorLength;
        port = inputPort;
        
        // Create queue for decoding frames
        char buffer[64];
        sprintf(buffer, "Decoding queue %d", port);
        decodingQueue = dispatch_queue_create(buffer, DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

- (void)dealloc
{
    NSLog(@"RtpDepacketiser exiting");
    [self closeSocket];
    
    for(int i = 0; i < FRAME_BUFFER_SIZE; i++)
        free(frameBuffer[i]);
    
    for(int i = 0; i < PACKET_BUFFER_SIZE; i++)
        free(packetPuffer[i]);
    
    //dispatch_release(decodingQueue); 
}

#pragma mark -
#pragma mark Reception over UDP

// Start listening for tranmission on a UDP port
- (void)openSocket
{
    NSLog(@"Listening on port %u", port);
    
    // Declare variables
    struct sockaddr_in si_me;
    
    // Create a server socket
    if((rxSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1)
        NSLog(@"Failed to create video Rx socket.");
    
    // Create the address
    memset((char *)&si_me, 0, sizeof(si_me));
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(port);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    
    // Bind address to socket
    if(bind(rxSocket, (struct sockaddr *) &si_me, sizeof(si_me)) == -1)
        NSLog(@"Failed to bind video Rx socket to address.");
}

- (void)closeSocket
{
    close(rxSocket);
}

- (void)startListening
{
    int amountRead;
    
    RtpPacketHeaderStruct *packetHeader;
    char *payloadDescriptor;
    
    char *payload;
    unsigned int payloadLength;
    
    // Create a fixed size buffer for reading packets into
    for(int i = 0; i < PACKET_BUFFER_SIZE; i++)
        packetPuffer[i] = malloc(MAX_PACKET_TOTAL_LENGTH);
        
    nextPacketIndex = 0;
    nextSequenceNum = 0;
    byteInFrameSoFar = 0;
    
    // Create fixed size buffer fro reading frames into
    for(int i = 0; i < FRAME_BUFFER_SIZE; i++)
        frameBuffer[i] = malloc(MAX_FRAME_LENGTH);
        
    currentFrameIndex = 0;
    currentFrame = frameBuffer[currentFrameIndex];
    
    // We skip displaying any frame that has one or more packets missing
    skipThisFrame = NO;
    
    // Begin listening for data
    for(;;)
    {
        // Otherwise, recieve and display frame
        @autoreleasepool
        {
            // First read the packet
            amountRead = recv(rxSocket, packetPuffer[nextPacketIndex], MAX_PACKET_TOTAL_LENGTH, 0);
            if (amountRead < 0)
            {
                NSLog(@"Bad return value from server socket recvrom().");
                return;
            }
            
            // Alias to packet header, payload descriptor and payload
            packetHeader = (RtpPacketHeaderStruct*)packetPuffer[nextPacketIndex];
            payloadDescriptor = (char*)(packetPuffer[nextPacketIndex] + sizeof(packetHeader));
            payload = packetPuffer[nextPacketIndex] + payloadHeaderLength;
            payloadLength = amountRead - payloadHeaderLength;
            incomingSequenceNum = ntohs(packetHeader->sequenceNum);
            incomingTimestamp = ntohl(packetHeader->timestamp);
            
            //NSLog(@"Recieved packet %u, payload length %u", incomingSequenceNum, payloadLength);
            
            // If we are not skipping this frame, examine the packet
            if(!skipThisFrame)
            {
                // Completely ignore old packets
                if(incomingSequenceNum < nextSequenceNum)
                {
                    NSLog(@"Warning saw an old packet");
                }
                // Store future packets for later (if we have buffer space)
                else if(incomingSequenceNum > nextSequenceNum)
                {
                    NSLog(@"Packet is from the future, buffering for later use");
                    nextPacketIndex++;
                    
                    if(nextPacketIndex == PACKET_BUFFER_SIZE)
                    {
                        NSLog(@"Packet buffer overflow occured, will have to skip this frame");
                        skipThisFrame = YES;
                        nextPacketIndex = 0;
                    }
                }
                // Otherwise, insert this packet (and also any others from the buffer) into the frame
                else
                {
                    // Insert the this packet
                    [self insertPacketIntoFrame:payload payloadDescriptor:payloadDescriptor 
                                  payloadLength:payloadLength markerSet:packetHeader->marker];
                    
                    // Try insert any packets from the buffer
                    for(int i = 0; i < nextPacketIndex; i++)
                    {
                        // Alias to packet header, payload descriptor and payload
                        packetHeader = (RtpPacketHeaderStruct*)packetPuffer[i];
                        payloadDescriptor = (char*)(packetPuffer[i] + sizeof(packetHeader));
                        payload = packetPuffer[i] + payloadHeaderLength;
                        payloadLength = amountRead - payloadHeaderLength;
                        incomingSequenceNum = ntohs(packetHeader->sequenceNum);
                        incomingTimestamp = ntohl(packetHeader->timestamp);
                        
                        if(incomingSequenceNum == nextSequenceNum)
                        {
                            // Insert packet
                            [self insertPacketIntoFrame:payload payloadDescriptor:payloadDescriptor 
                                          payloadLength:payloadLength markerSet:packetHeader->marker];
                            
                            // Remove packet from the buffer
                            if(nextPacketIndex > 1)
                            {
                                packetPuffer[i] = packetPuffer[nextPacketIndex-1];
                                nextPacketIndex--;
                            }
                            else 
                                nextPacketIndex = 0;
                            
                            // Reset iterator so we loop through again
                            i = 0;
                        }
                    }
                }
            }
            // If we are skipping this frame, we don't do anything till a marker packet
            else if(packetHeader->marker)
            {
                NSLog(@"Resetting after skip");
                // Reset state so the next frame can be decoded
                byteInFrameSoFar = 0;
                skipThisFrame = NO;
                nextSequenceNum = incomingSequenceNum + 1;
            }
        }
    }
}

- (void)insertPacketIntoFrame:(char*)payload payloadDescriptor:(char*)payloadDescriptor
                payloadLength:(unsigned int)payloadLength markerSet:(Boolean)marker
{
    // Insert packet into frame
    memcpy(currentFrame + byteInFrameSoFar, payload, payloadLength);
    byteInFrameSoFar += payloadLength;
    nextSequenceNum++;
    
    // If mark is set, this is the last packet of the frame
    if(marker)
    {
        // Wait till queue is empty
        dispatch_sync(decodingQueue, ^{});
        
        // Queue up a frame to be decoded
        NSData *frameData = [NSData dataWithBytesNoCopy:currentFrame length:byteInFrameSoFar freeWhenDone:NO];
        dispatch_async(decodingQueue, ^{
            [self.delegate processEncodedData:frameData];
        });
        
        // Swap frames so we don't write into the old one whilst decoding, and reset counter
        currentFrameIndex = (currentFrameIndex + 1) % FRAME_BUFFER_SIZE;
        currentFrame = frameBuffer[currentFrameIndex];
        byteInFrameSoFar = 0;
    }
}

@end
