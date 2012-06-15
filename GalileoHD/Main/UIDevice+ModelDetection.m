//  Created by Chris Harding on 24/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#include <sys/types.h>
#include <sys/sysctl.h>
#import "UIDevice+ModelDetection.h"

@implementation UIDevice (ModelDetection)

/*
 Platforms
 iPhone1,1 -> iPhone 1G
 iPhone1,2 -> iPhone 3G 
 iPod1,1   -> iPod touch 1G 
 iPod2,1   -> iPod touch 2G 
 */

- (NSString *) platform
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return platform;
}

@end
