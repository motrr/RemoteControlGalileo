#ifndef Socket_H
#define Socket_H

#include <string>

// BSD sockets
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>

class Socket
{
public:
    Socket();
    ~Socket();
    
    bool openSocket(const std::string &ipAddress, u_short port, size_t maxPacketLength);
    bool sendPacket(const void *buffer, size_t size);

private:
    void closeSocket(); // autoclose on destroy

    // Sending vars
    sockaddr_in mSocketAddress;
    int mSocketId;
};

#endif


