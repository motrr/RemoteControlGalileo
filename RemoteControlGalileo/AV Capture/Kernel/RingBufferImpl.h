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

inline RingBuffer::RingBuffer(size_t elementSize):
	mElementSizeBytes(elementSize),
	mBufferSize(0),
	mBuffer(0)
{
    clear();
}

inline RingBuffer::RingBuffer(size_t bufferSize, size_t elementSize):
    mElementSizeBytes(elementSize),
	mBufferSize(0),
	mBuffer(0)
{
    resize(bufferSize);
    clear();
}

inline RingBuffer::~RingBuffer()
{
    delete [] mBuffer;
    mBuffer = 0;
}

inline void RingBuffer::resize(size_t bufferSize)
{
	// min size == 4
    bufferSize = bufferSize < 4 ? 4 : bufferSize;

    // round up to the next power of 2
    size_t index = ~0;
    for(size_t i = 0; i < sizeof(size_t) * 8; ++i)
    {
        if(bufferSize >> i & 0x01) index = i;
    }
    
    assert(index != ~0);
    if(bufferSize <= size_t(0x01 << index))
        bufferSize = 0x01 << index;
    else
        bufferSize = 0x01 << (index + 1);
    
    //
	if(mBuffer)
	{
		char *newBuffer = new char[bufferSize * mElementSizeBytes];
		pop(newBuffer, size());

		delete [] mBuffer;
		mBuffer = newBuffer;
	}
	else
	{
		mBuffer = new char[bufferSize * mElementSizeBytes];
	}
    
	mBufferSize = bufferSize;
    mBigMask = (bufferSize * 2) - 1;
    mSmallMask = bufferSize - 1;
}

inline void RingBuffer::clear()
{
    mWriteIndex.set(0);
    mReadIndex.set(0);
}

inline size_t RingBuffer::capacity() const
{
    return mBufferSize;
}

inline size_t RingBuffer::size() const
{
    return (mWriteIndex.get() - mReadIndex.get()) & mBigMask;
}

inline bool RingBuffer::empty() const
{
    return mWriteIndex.get() == mReadIndex.get();
}

inline size_t RingBuffer::push(const void *samples, size_t numSamples)
{
	// we dont realy care if we got old data here, we will just write less, thats all
	size_t writeIndex = mWriteIndex.get();
    size_t readIndex = mReadIndex.get();
	size_t size = (writeIndex - readIndex) & mBigMask; 
	if(size == mBufferSize) return 0;

	size = mBufferSize - size; 
	if(numSamples > size) numSamples = size;

	//
	size_t index = writeIndex & mSmallMask;
    if((index + numSamples) > mBufferSize)
    {
		size_t firstHalf = mBufferSize - index;
		memcpy(&mBuffer[index * mElementSizeBytes], samples, firstHalf * mElementSizeBytes);
		samples = ((char *)samples) + firstHalf * mElementSizeBytes;
		memcpy(mBuffer, samples, (numSamples - firstHalf) * mElementSizeBytes);
    }
    else
    {
		memcpy(&mBuffer[index * mElementSizeBytes], samples, numSamples * mElementSizeBytes);
    }
    
	// this should be the last operation
	mWriteIndex.set((writeIndex + numSamples) & mBigMask);
    return numSamples;
}

inline size_t RingBuffer::pop(void *output, size_t numSamples)
{
	// we dont realy care if we got old data here, we will just read less, thats all
	size_t writeIndex = mWriteIndex.get();
    size_t readIndex = mReadIndex.get();
	size_t size = (writeIndex - readIndex) & mBigMask; 
	if(size == 0) return 0;
	if(numSamples > size) numSamples = size;

	//
	size_t index = readIndex & mSmallMask;
    if((index + numSamples) > mBufferSize)
    {
		size_t firstHalf = mBufferSize - index;
		memcpy(output, &mBuffer[index * mElementSizeBytes], firstHalf * mElementSizeBytes);
		output = ((char *)output) + firstHalf * mElementSizeBytes;
		memcpy(output, mBuffer, (numSamples - firstHalf) * mElementSizeBytes);
    }
    else
    {
		memcpy(output, &mBuffer[index * mElementSizeBytes], numSamples * mElementSizeBytes);
    }
    
	// this should be the last operation
	mReadIndex.set((readIndex + numSamples) & mBigMask);
    return numSamples;
}
