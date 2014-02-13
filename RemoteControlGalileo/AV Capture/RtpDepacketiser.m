#import "RtpDepacketiser.h"
#import "VideoTxRxCommon.h"

#import <sys/socket.h>
#import <netinet/in.h>

// PACKET_SEQUENCE_DIFF - minimal difference between seq. numbers from last inserted packet 
// and minimal seq. number from packet list when we will discart packets to the next keyframe
// invalid/old packets.
#define PACKET_SEQUENCE_DIFF 5
#define PACKET_BUFFER_SIZE 25
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
    char *packetBuffer[PACKET_BUFFER_SIZE];
    int packetBufferLength[PACKET_BUFFER_SIZE];
    unsigned int nextPacketIndex;
    unsigned int nextSequenceNum;
    unsigned int byteInFrameSoFar;
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
        free(packetBuffer[i]);
    
    //dispatch_release(decodingQueue); 
}

- (BOOL)hasKeyframes
{
    return NO;
}

- (BOOL)isKeyframe:(char *)payloadDescriptor
{
    return NO;
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
    rxSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if(rxSocket == -1)
        NSLog(@"Failed to create video Rx socket.");
    
    // Create the address
    memset((char *)&si_me, 0, sizeof(si_me));
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(port);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    
    // Get or set the send buffer size
    /*unsigned int x = 32768;//maxPacketLength * 64;
    unsigned int y = sizeof(x);
    printf("Attempting to set socket recieve buffer to %u bytes\n", x);
    setsockopt(rxSocket, SOL_SOCKET, SO_RCVBUF, &x, y);
    getsockopt(rxSocket, SOL_SOCKET, SO_RCVBUF, &x, &y);
    printf("Socket recieve buffer is %u bytes\n", x);*/
    
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
    // Create a fixed size buffer for reading packets into
    for(int i = 0; i < PACKET_BUFFER_SIZE; i++)
    {
        packetBufferLength[i] = 0;
        packetBuffer[i] = malloc(MAX_PACKET_TOTAL_LENGTH);
        memset(packetBuffer[i], 0, MAX_PACKET_TOTAL_LENGTH);
    }
    
    nextPacketIndex = 0;
    nextSequenceNum = 1;
    byteInFrameSoFar = 0;
    
    // Create fixed size buffer fro reading frames into
    for(int i = 0; i < FRAME_BUFFER_SIZE; i++)
        frameBuffer[i] = malloc(MAX_FRAME_LENGTH);
        
    currentFrameIndex = 0;
    currentFrame = frameBuffer[currentFrameIndex];
    
    // We skip displaying any frame that has one or more packets missing
    int notInsertedCounter = 0;
    int lastInsertedSequenceNum = 0;
    
    // Begin listening for data
    for(;;)
    {
        // Otherwise, recieve and display frame
        @autoreleasepool
        {
            // 1. Read packet
            packetBufferLength[nextPacketIndex] = recv(rxSocket, packetBuffer[nextPacketIndex], MAX_PACKET_TOTAL_LENGTH, 0);
            if (packetBufferLength[nextPacketIndex] < 0)
            {
                NSLog(@"Bad return value from server socket recvrom().");
                perror("recv");
                return;
            }
            
            // 2. Insert packets to frame
            int lastInsertedIndex = -1;
            
            //NSLog(@"incomingSequenceNum #%u:", ntohs(((RtpPacketHeaderStruct*)packetBuffer[nextPacketIndex])->sequenceNum));
            
            for(int i = 0; i < PACKET_BUFFER_SIZE; i++)
            {
                RtpPacketHeaderStruct *packetHeader = (RtpPacketHeaderStruct*)packetBuffer[i];
                char *payloadDescriptor = (char*)(packetBuffer[i] + sizeof(RtpPacketHeaderStruct));
                char *payload = packetBuffer[i] + payloadHeaderLength;
                unsigned int payloadLength = packetBufferLength[i] - payloadHeaderLength;
                unsigned int incomingSequenceNum = ntohs(packetHeader->sequenceNum);
                
                // Check sequence
                if(incomingSequenceNum == nextSequenceNum)
                {
                    [self insertPacketIntoFrame:payload payloadDescriptor:payloadDescriptor
                                  payloadLength:payloadLength markerSet:packetHeader->marker];
                    
                    // Save last inserted index 
                    lastInsertedIndex = i;
                    lastInsertedSequenceNum = incomingSequenceNum;
                    
                    // Iterate one more time to check other packets
                    // to be inserted after current
                    i = -1;
                }
            }
            
            // 3. If no packets was inserted
            if(lastInsertedIndex == -1)
            {
                RtpPacketHeaderStruct *packetHeader = (RtpPacketHeaderStruct*)packetBuffer[nextPacketIndex];
                Vp8PayloadDescriptorStruct *payloadDescriptor = (Vp8PayloadDescriptorStruct*)(packetHeader + sizeof(RtpPacketHeaderStruct));
                char *payload = packetBuffer[nextPacketIndex] + payloadHeaderLength;
                unsigned int payloadLength = packetBufferLength[nextPacketIndex] - payloadHeaderLength;
                unsigned int nextPacketSequenceNum = ntohs(packetHeader->sequenceNum);
                
                // Increase not inserted packets counter
                notInsertedCounter++;
                
                // Check unsended packets counter for overflow
                if(notInsertedCounter > PACKET_BUFFER_SIZE || nextPacketSequenceNum - lastInsertedSequenceNum >= PACKET_SEQUENCE_DIFF)
                {
                    //NSLog(@"Searching #%u:", nextSequenceNum);
                    
                    if(![self hasKeyframes])
                    {
                        if(packetHeader->marker)
                        {
                            notInsertedCounter = 0;
                            byteInFrameSoFar   = 0;
                            
                            nextSequenceNum = nextPacketSequenceNum + 1;
                            
                            NSLog(@"Skipping to the next packet #%u", nextSequenceNum);
                        }
                    }
                    else
                    {
                        if([self isKeyframe:(char*)payloadDescriptor])
                        {
                            notInsertedCounter = 0;
                            byteInFrameSoFar   = 0;
                            nextSequenceNum    = nextPacketSequenceNum;
                            lastInsertedSequenceNum = nextSequenceNum;
                            lastInsertedIndex = nextPacketIndex;
                            
                            NSLog(@"Skipping to the next key frame packet #%u", nextSequenceNum);
                            
                            [self insertPacketIntoFrame:payload payloadDescriptor:(char*)payloadDescriptor
                                  payloadLength:payloadLength markerSet:packetHeader->marker];
                        }
                    }
                }
                
                if(lastInsertedIndex < 0)
                {
                    // Reuse buffer's packet slot with minimum sequence value
                    int minSeqIndex = 0;
                    unsigned int minSeq = -1;
                    
                    for(int i = 0; i < PACKET_BUFFER_SIZE; i++)
                    {
                        int seq = ntohs(((RtpPacketHeaderStruct*)packetBuffer[i])->sequenceNum);
                        
                        if(minSeq > seq)
                        {
                            minSeqIndex = i;
                            minSeq = seq;
                        }
                    }
                    
                    nextPacketIndex = minSeqIndex;
                }
            }
            else
            {
                // If some frame was inserted reset counter
                notInsertedCounter = 0;
                
                // Reuse just inserted packet slot
                nextPacketIndex = lastInsertedIndex;
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
