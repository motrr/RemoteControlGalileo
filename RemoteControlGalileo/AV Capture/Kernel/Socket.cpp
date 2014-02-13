#include "Socket.h"
#include <assert.h>

#define INVALID_SOCKET -1

Socket::Socket():
    mSocketId(INVALID_SOCKET)
{
}

Socket::~Socket()
{
    if(mSocketId != INVALID_SOCKET)
        closeSocket();
}

bool Socket::openSocket(const std::string &ipAddress, u_short port, size_t maxPacketLength)
{
    assert(mSocketId == INVALID_SOCKET);
    printf("Opening UDP socket with destination IP %s on port %hu\n", ipAddress.c_str(), port);
    
    // Create socket
    mSocketId = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if(mSocketId == INVALID_SOCKET)
    {
        printf("Failed to create socket\n");
        return false;
    }
    
    // Create address
    memset((char *)&mSocketAddress, 0, sizeof(mSocketAddress));
    mSocketAddress.sin_family = AF_INET;
    mSocketAddress.sin_port = htons(port);
    
    // Process IP address string to network address
    if(inet_aton(ipAddress.c_str(), &mSocketAddress.sin_addr) == 0)
    {
        printf("Error: inet_aton() failed\n");
        return false;
    }
    
    // Get or set the send buffer size
    //unsigned int x = 32768;
    unsigned int x = maxPacketLength;
    unsigned int y = sizeof(x);
    printf("Attempting to set socket send buffer to %u bytes\n", x);
    setsockopt(mSocketId, SOL_SOCKET, SO_SNDBUF, &x, y);
    getsockopt(mSocketId, SOL_SOCKET, SO_SNDBUF, &x, &y);
    printf("Socket send buffer is %u bytes\n", x);
    
    return true;
}

void Socket::closeSocket()
{
    assert(mSocketId != INVALID_SOCKET);
    close(mSocketId);
    mSocketId = INVALID_SOCKET;
}

bool Socket::sendPacket(const void *buffer, size_t size)
{
    assert(mSocketId != INVALID_SOCKET);
    
    // Send fragment over socket
    if(sendto(mSocketId, buffer, size, 0, (struct sockaddr*)&mSocketAddress, sizeof(mSocketAddress)) == -1)
    {
        printf("Error when sending packet\n");
        return false;
    }
    
    return true;
}