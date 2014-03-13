//
//  Copyright (c) 2013 Bohdan Marchuk. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "Hardware.h"

#ifdef __APPLE__
#include <sys/sysctl.h>
#endif

#include <string>

namespace Hardware
{
    
Family getFamily()
{
    Model type = getModel();
#ifdef __APPLE__
    if(type == HM_Simulator) return HF_Simulator;
    if(type <= HM_iPod_5g) return HF_iPod;
    if(type <= HM_iPhone_5) return HF_iPhone;
    if(type <= HM_iPad_3) return HF_iPad;
#endif
    
    return HF_Unknown;
}

Model getModel()
{
#ifdef __APPLE__
    const std::string names[] = { "i386",       // simulator
                                  "iPod1",      // iPod Touch (iPod1,1)
                                  "iPod2",      // iPod Touch 2g (iPod2,1)
                                  "iPod3",      // iPod Touch 3g (iPod3,1)
                                  "iPod4",      // iPod Touch 4g (iPod4,1)
                                  "iPod5",      // iPod Touch 5g (iPod5,1)?!
                                  "iPhone1,1",  // iPhone
                                  "iPhone1,2",  // iPhone 3g
                                  "iPhone2",    // iPhone 3gs (iPhone2,1)
                                  "iPhone3",    // iPhone 4 (iPhone3,1)
                                  "iPhone4",    // iPhone 4S (iPhone4,1)
                                  "iPhone5",    // iPhone 5 (iPhone5,1) ?!
                                  "iPad1",      // iPad (iPad1,1)
                                  "iPad2",      // iPad 2 (iPad2,1)
                                  "iPad3",      // iPad 3 (iPad3,1) ?!
                                  "iPad2,5",    // iPad Mini (iPad2,5)
    };

    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    
    std::string machine;
    machine.resize(size);
    sysctlbyname("hw.machine", &machine[0], &size, NULL, 0);
    //printf("Device type: %s\n", machine());
    
    for(int i = HM_Simulator; i < HM_Unknown; i++)
    {
        if(std::equal(names[i].begin(), names[i].end(), machine.begin()))
            return (Model)i;
    }
    
    // device type unknown
    if(machine.substr(0, 6) == "iPhone")
    {
        int version = machine[6] - '0';
        if(version > 4) version = 4;
        if(version < 0) version = 0;
        return (Model)(HM_iPhone_1g + version);
    }
    else if(machine.substr(0, 4) == "iPod")
    {
        int version = machine[4] - '0';
        if(version > 5) version = 5;
        if(version < 1) version = 1;
        return (Model)(HM_iPod_1g + version - 1);
    }
    else if(machine.substr(0, 4) == "iPad")
    {
        int version = machine[4] - '0';
        if(version > 3) version = 3;
        if(version < 1) version = 1;
        return (Model)(HM_iPad + version - 1);
    }
#endif
    
    return HM_Unknown;
}

}