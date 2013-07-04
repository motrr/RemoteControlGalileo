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

#ifndef Function_H
#define Function_H

#include <memory>

#ifdef __APPLE__
#include <objc/runtime.h>
#endif

// Usage:
// int someFunc(float int) {}
// Function<int(float, int)> func(&someFunc);
//
// int SomeClass::someFunc(float int) {}
// SomeClass val;
// Function<int(float, int)> func(&val, &SomeClass::someFunc);
//
// @interface SomeClass
// - (int)someFunc:(float) intVal:(int) {}
// @end
// SomeClass *val = [[SomeClass alloc] init];
// Function<int(float, int)> func(val, @selector(someFunc:intVal:));
//
// Binding:
// Function<int(float, int)> func = bind(&someFunc);
// Function<int(float, int)> func = bind(&val, &SomeClass::someFunc);
// Function<int(float, int)> func = bind<float, int, int>(val, @selector(someFunc:intVal:));
// int val = bind(&val, &SomeClass::someFunc)(10.f, 20); // direct usage ^_^
//
// Invokating:
// int val = func(10.f, 20);
//
// Some more examples:
// Function<void()> func;
// Function<void(int, int, int)> func;
//
// Function##index<arguments ..., return type>
// Function0<void> == Function<void()>
// Function1<int, void> == Function<void(int)>
// Function3<float, char, int, void> == Function<void(float, char, int)>
//
// support up to 3 params, but can be extended :)
// todo: check whenever virtual member functions are working correctly

// Declare Function as a class template. It will be specialized later for all number of arguments.
template <typename Signature>
class Function;

// Parent class to make compare work, hack:
class FunctionBase
{
public:
    virtual ~FunctionBase() {}
};


// 0 members
#define FunctionClassName Function0
#define FunctionSeparator
#define FunctionTemplateParams
#define FunctionTemplateArgs
#define FunctionParams
#define FunctionArgs

#include "FunctionTemplate.h"

#undef FunctionClassName
#undef FunctionSeparator
#undef FunctionTemplateParams
#undef FunctionTemplateArgs
#undef FunctionParams
#undef FunctionArgs

// 1 member
#define FunctionClassName Function1
#define FunctionSeparator ,
#define FunctionTemplateParams class Param1
#define FunctionTemplateArgs Param1
#define FunctionParams Param1 p1
#define FunctionArgs p1

#include "FunctionTemplate.h"

#undef FunctionClassName
#undef FunctionSeparator
#undef FunctionTemplateParams
#undef FunctionTemplateArgs
#undef FunctionParams
#undef FunctionArgs

// 2 member
#define FunctionClassName Function2
#define FunctionSeparator ,
#define FunctionTemplateParams class Param1, class Param2
#define FunctionTemplateArgs Param1, Param2
#define FunctionParams Param1 p1, Param2 p2
#define FunctionArgs p1, p2

#include "FunctionTemplate.h"

#undef FunctionClassName
#undef FunctionSeparator
#undef FunctionTemplateParams
#undef FunctionTemplateArgs
#undef FunctionParams
#undef FunctionArgs

// 3 member
#define FunctionClassName Function3
#define FunctionSeparator ,
#define FunctionTemplateParams class Param1, class Param2, class Param3
#define FunctionTemplateArgs Param1, Param2, Param3
#define FunctionParams Param1 p1, Param2 p2, Param3 p3
#define FunctionArgs p1, p2, p3

#include "FunctionTemplate.h"

#undef FunctionClassName
#undef FunctionSeparator
#undef FunctionTemplateParams
#undef FunctionTemplateArgs
#undef FunctionParams
#undef FunctionArgs

#endif