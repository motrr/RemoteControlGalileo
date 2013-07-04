//  Created by Chris Harding on 04/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Methods for obtaining local IP addres. Works in simulator as well as real device.

#ifndef GalileoWifi_IpAddress_h
#define GalileoWifi_IpAddress_h

#define MAXADDRS 32

// todo: make singleton!
class IpAddress
{
public:
    static void init();
    static void free();

    static bool hasIpAddress();
    static void updateIpAddresses();
    static void updateHwAddresses();
    
    static char *getIfName(int index) { return mIfNames[index]; }
    static char *getIpName(int index) { return mIpNames[index]; }
    static char *getHwAddress(int index) { return mHwAddresses[index]; }
    static unsigned long getIpAddress(int index) { return mIpAddresses[index]; }

private:
    static char *mIfNames[MAXADDRS];
    static char *mIpNames[MAXADDRS];
    static char *mHwAddresses[MAXADDRS];
    static unsigned long mIpAddresses[MAXADDRS];

    static bool mHasIpAddress;
    static int mNextAddress;
};

#endif
