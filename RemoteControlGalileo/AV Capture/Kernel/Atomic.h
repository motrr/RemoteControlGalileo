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

#ifndef Atomic_H
#define Atomic_H

#include <stdint.h>

//#define USE_RELAXED_GET

template <typename Type, typename StorageType = uint32_t>
class Atomic
{
public:
	Atomic() : mValue(0) {}
	explicit Atomic(Type value) : mValue(static_cast<StorageType>(value)) {}
	
#ifdef USE_RELAXED_GET
	Type get() const { return mValue; } // relaxed
#else
	Type get() const;
#endif
	Type set(Type value);
	Type add(Type value);
	Type sub(Type value);

	Type operator++() { return add(1) + 1; }
	Type operator--() { return sub(1) - 1; }
	Type operator++(int) { return add(1); }
	Type operator--(int) { return sub(1); }

private:
	volatile StorageType mValue;
};

namespace Barrier
{
	void hardware();
	void compiler();
};

#if defined(_WIN64) || defined(_WIN32)

#define _WINIOCTL_ // avoid defines of ELEMENT_TYPE
#define NOMINMAX // required to stop windows.h messing up std::min
#include <windows.h>

inline void Barrier::hardware() { ::MemoryBarrier(); }
inline void Barrier::compiler() { ::_ReadWriteBarrier(); }

#ifndef USE_RELAXED_GET
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::get() const { Type value = static_cast<Type>(mValue); Barrier::hardware(); return value; } // aquire
#endif
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::set(Type value) { return static_cast<Type>(InterlockedExchange(&mValue, value)); }
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::add(Type value) { return static_cast<Type>(InterlockedExchangeAdd(&mValue, value)); }
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::sub(Type value) { return static_cast<Type>(InterlockedExchangeSubtract(&mValue, value)); }

#elif defined(__GNUC__) && (__GNUC__ * 100 + __GNUC_MINOR__ >= 401)

inline void Barrier::hardware() { __sync_synchronize(); }
inline void Barrier::compiler() { __sync_synchronize(); }

#ifndef USE_RELAXED_GET
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::get() const { Type value = static_cast<Type>(mValue); Barrier::hardware(); return value; } // aquire
#endif
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::add(Type value) { return static_cast<Type>(__sync_fetch_and_add(const_cast<uint32_t *>(&mValue), value)); }
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::sub(Type value) { return static_cast<Type>(__sync_fetch_and_sub(const_cast<uint32_t *>(&mValue), value)); }
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::set(Type value) { Type old = static_cast<Type>(mValue); Barrier::hardware(); mValue = static_cast<StorageType>(value); return old; }

#elif defined(__GNUC__) && (defined(__i386__) || defined(__x86_64__))

inline void Barrier::hardware() { asm volatile("mfence":::"memory"); }
inline void Barrier::compiler() { asm volatile("mfence":::"memory"); }

inline uint32_t atomicAdd(uint32_t value)
{
	// int r = *pw;
	// *mem += val;
	// return r;
	int r;
	asm volatile
	(
		"lock\n\t"
		"xadd %1, %0":
		"+m"( mValue ), "=r"( r ): // outputs (%0, %1)
		"1"( value ): // inputs (%2 == %1)
		"memory", "cc" // clobbers
	);

	return r;
}

#ifndef USE_RELAXED_GET
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::get() const { Type value = static_cast<Type>(mValue); Barrier::hardware(); return value; } // aquire
#endif
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::add(Type value) { return static_cast<Type>(atomicAdd(uint32_t(value))); }
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::sub(Type value) { return static_cast<Type>(atomicAdd(uint32_t(-value))); }
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::set(Type value) { Type old = static_cast<Type>(mValue); Barrier::hardware(); mValue = static_cast<StorageType>(value); return old; }

#elif defined(__GNUC__) && (defined(__PPC__) || defined(__ppc__))

inline void Barrier::hardware() { asm volatile("sync":::"memory"); }
inline void Barrier::compiler() { asm volatile("sync":::"memory"); }

inline uint32_t atomicAdd(uint32_t value)
{
	uint32_t prev, temp;
	asm volatile ("0:\n\t"                 // retry local label     
				"lwarx  %0,0,%2\n\t"       // load prev and reserve 
				"add    %1,%0,%3\n\t"      // temp = prev + val   
				"stwcx. %1,0,%2\n\t"       // conditionally store   
				"bne-   0b"                // start over if we lost
											// the reservation
				//XXX find a cleaner way to define the temp         
				//it's not an output
				: "=&r" (prev), "=&r" (temp)        // output, temp 
				: "b" (&mValue), "r" (value)        // inputs       
				: "memory", "cc");                  // clobbered    
	return prev;
}

#ifndef USE_RELAXED_GET
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::get() const { Type value = static_cast<Type>(mValue); Barrier::hardware(); return value; } // aquire
#endif
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::add(Type value) { return static_cast<Type>(atomicAdd(uint32_t(value))); }
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::sub(Type value) { return static_cast<Type>(atomicAdd(uint32_t(-value))); }
template <typename Type, typename StorageType>
inline Type Atomic<Type, StorageType>::set(Type value) { Type old = static_cast<Type>(mValue); Barrier::hardware(); mValue = static_cast<StorageType>(value); return old; }

#endif
#endif