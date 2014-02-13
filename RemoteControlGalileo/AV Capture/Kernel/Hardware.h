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

#ifndef Hardware_H
#define Hardware_H

// todo: add support for other hardware
// right now only iOS devices ^_^

namespace Hardware
{
    enum Model
    {
        HM_Simulator = 0, // ^_^
        HM_iPod_1g,
        HM_iPod_2g,
        HM_iPod_3g,
        HM_iPod_4g,
        HM_iPod_5g, // any newer models, currently 
        HM_iPhone_1g,
        HM_iPhone_3g,
        HM_iPhone_3gs,
        HM_iPhone_4,
        HM_iPhone_4s,
        HM_iPhone_5,
        HM_iPad,
        HM_iPad_2,
        HM_iPad_3,
        HM_iPadMini,
        HM_Unknown,
    };

    enum Family
    {
        HF_Simulator = 0,
        HF_iPod,
        HF_iPhone,
        HF_iPad,
        HF_Unknown
    };

    Model getModel();
    Family getFamily();
}

#endif 
