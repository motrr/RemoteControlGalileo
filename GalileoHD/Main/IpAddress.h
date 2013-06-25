//  Created by Chris Harding on 04/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Methods for obtaining local IP addres. Works in simulator as well as real device.

#ifndef GalileoWifi_IpAddress_h
#define GalileoWifi_IpAddress_h

#define MAXADDRS	32

extern char *if_names[MAXADDRS];
extern char *ip_names[MAXADDRS];
extern char *hw_addrs[MAXADDRS];
extern unsigned long ip_addrs[MAXADDRS];

extern int already_got_ip_address;

// Function prototypes
void InitAddresses();
void FreeAddresses();
void GetIPAddresses();
void GetHWAddresses();

#endif
