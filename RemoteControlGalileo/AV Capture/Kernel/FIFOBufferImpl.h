template<class SampleType>
FIFOBuffer<SampleType>::FIFOBuffer()
{
    mSizeInBytes = 0; // reasonable initial value
    mBuffer = NULL;
    mBufferUnaligned = NULL;
    mSamplesInBuffer = 0;
    mBufferPosition = 0;
    ensureCapacity(32); // allocate initial capacity 
}

template<class SampleType>
FIFOBuffer<SampleType>::~FIFOBuffer()
{
    delete [] mBufferUnaligned;
    mBufferUnaligned = NULL;
    mBuffer = NULL;
}

template<class SampleType>
void FIFOBuffer<SampleType>::rewind()
{
    if(mBuffer && mBufferPosition) 
    {
        memmove(mBuffer, begin(), sizeof(SampleType) * mSamplesInBuffer);
        mBufferPosition = 0;
    }
}

template<class SampleType>
void FIFOBuffer<SampleType>::push(const SampleType *samples, size_t numSamples)
{
    memcpy(end(numSamples), samples, sizeof(SampleType) * numSamples);
    mSamplesInBuffer += numSamples;
}

template<class SampleType>
void FIFOBuffer<SampleType>::push(size_t numSamples)
{
    size_t required = mSamplesInBuffer + numSamples;
    ensureCapacity(required);
    mSamplesInBuffer += numSamples;
}

template<class SampleType>
SampleType *FIFOBuffer<SampleType>::end(size_t slackCapacity) 
{
    ensureCapacity(mSamplesInBuffer + slackCapacity);
    return mBuffer + mSamplesInBuffer;
}

template<class SampleType>
SampleType *FIFOBuffer<SampleType>::begin()
{
    assert(mBuffer);
    return mBuffer + mBufferPosition;
}

template<class SampleType>
void FIFOBuffer<SampleType>::ensureCapacity(size_t capacityRequirement)
{
    if(capacityRequirement > getCapacity())
    {
        // Helper macro for aligning pointer up to next 16-byte boundary
        #define ALIGN_POINTER_16(x) (((ptrdiff_t)(x) + 15 ) & ~(ptrdiff_t)15)
        
        // enlarge the mBuffer in 4kbyte steps (round up to next 4k boundary)
        mSizeInBytes = (capacityRequirement * sizeof(SampleType) + 4095) & (size_t)-4096;
        assert(mSizeInBytes % 2 == 0);
        SampleType *tempUnaligned = new SampleType[mSizeInBytes / sizeof(SampleType) + 16 / sizeof(SampleType)];
        if(tempUnaligned == NULL)
        {
            printf("Couldn't allocate memory!\n");
            assert(false);
        }
        // Align the mBuffer to begin at 16byte cache line boundary for optimal performance
        SampleType *temp = (SampleType *)ALIGN_POINTER_16(tempUnaligned);
        if (mSamplesInBuffer)
        {
            memcpy(temp, begin(), mSamplesInBuffer * sizeof(SampleType));
        }
        delete[] mBufferUnaligned;
        mBuffer = temp;
        mBufferUnaligned = tempUnaligned;
        mBufferPosition = 0;
    } 
    else 
    {
        // simply rewind the mBuffer (if necessary)
        rewind();
    }
}

template<class SampleType>
size_t FIFOBuffer<SampleType>::getCapacity() const
{
    return mSizeInBytes / sizeof(SampleType);
}

template<class SampleType>
size_t FIFOBuffer<SampleType>::size() const
{
    return mSamplesInBuffer;
}

template<class SampleType>
size_t FIFOBuffer<SampleType>::pop(SampleType *output, size_t maxSamples)
{
    size_t numSamples = (maxSamples > mSamplesInBuffer) ? mSamplesInBuffer : maxSamples;
    memcpy(output, begin(), sizeof(SampleType) * numSamples);
    return pop(numSamples);
}

template<class SampleType>
size_t FIFOBuffer<SampleType>::pop(size_t maxSamples)
{
    if(maxSamples >= mSamplesInBuffer)
    {
        size_t temp = mSamplesInBuffer;
        mSamplesInBuffer = 0;
        return temp;
    }

    mSamplesInBuffer -= maxSamples;
    mBufferPosition += maxSamples;
    return maxSamples;
}

template<class SampleType>
bool FIFOBuffer<SampleType>::empty() const
{
    return (mSamplesInBuffer == 0);
}

template<class SampleType>
void FIFOBuffer<SampleType>::clear()
{
    mSamplesInBuffer = 0;
    mBufferPosition = 0;
}

template<class SampleType>
size_t FIFOBuffer<SampleType>::trim(size_t numSamples)
{
    if(numSamples < mSamplesInBuffer)
        mSamplesInBuffer = numSamples;

    return mSamplesInBuffer;
}

