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

#ifndef RingBuffer_H
#define RingBuffer_H

#include "Atomic.h"
#include <memory.h>
#include <string.h>
#include <assert.h>

// @brief Single-reader single-writer lock-free ring buffer
// 
// Ring buffer used to transport samples between
// different execution contexts (threads, OS callbacks, interrupt handlers)
// without requiring the use of any locks. This only works when there is
// a single reader and a single writer (ie. one thread or callback writes
// to the ring buffer, another thread or callback reads from it).

// Number of elements in buffer must be a power of two. An element may be any size 
// (specified in bytes).

// todo: make template?
class RingBuffer
{
public:
	RingBuffer(size_t elementSize);
    RingBuffer(size_t bufferSize, size_t elementSize); // in case buffer size is not power of 2, it will be adjusted.
    ~RingBuffer();

    // Adds 'numSamples' pcs of samples from the 'samples' memory position to
    // the sample buffer. == sizeof(Type) * numSamples
    //
    // \return Number of samples actualy written returned.
    size_t push(const void *samples, size_t numSamples);

    // Output samples from beginning of the sample buffer. Copies requested samples to 
    // output buffer and removes them from the sample buffer. If there are less than 
    // 'numsample' samples in the buffer, returns all that available.
    //
    // \return Number of samples returned.
    size_t pop(void *output, size_t numSamples);

    // Retrieve the number of elements available in the ring buffer for reading.
    size_t size() const; // relaxed memory model

    // Return size of allocated storage capacity, expressed in terms of elements.
    size_t capacity() const;

    // Returns nonzero if there aren't any samples available for outputting.
    bool empty() const; // relaxed memory model

    // Clears all the samples.
    // Reset buffer to empty. Should only be called when buffer is NOT being read or written.
    void clear();

	// Resize the buffer, won't fill with zeros!
	// in case buffer size is not power of 2, it will be adjusted.
	void resize(size_t bufferSize); // is not thread safe!!

private:
    // Sample buffer.
    char *mBuffer;

    // Number of elements in FIFO. Power of 2.
    size_t mBufferSize;
    
    // Number of bytes per element.
    size_t mElementSizeBytes;
    
    Atomic<uint32_t> mWriteIndex; // Index of next writable element.
    Atomic<uint32_t> mReadIndex; // Index of next readable element.

    size_t mBigMask;    // Used for wrapping indices with extra bit to distinguish full/empty.
    size_t mSmallMask;  // Used for fitting indices to buffer.
};

#include "RingBufferImpl.h"

#endif
