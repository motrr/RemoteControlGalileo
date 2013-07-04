#ifndef FIFOBuffer_H
#define FIFOBuffer_H

#include <stdlib.h>
#include <memory.h>
#include <string.h>
#include <assert.h>

template<class SampleType>
class FIFOBuffer
{
public:
    FIFOBuffer();
    ~FIFOBuffer();

    // Returns a pointer to the beginning of the output samples. 
    // This function is provided for accessing the output samples directly. 
    // Please be careful for not to corrupt the book-keeping!
    //
    // When using this function to output samples, also remember to 'remove' the
    // output samples from the buffer by calling the 
    // 'pop(numSamples)' function
    SampleType *begin();

    // Returns a pointer to the end of the used part of the sample buffer (i.e. 
    // where the new samples are to be inserted). This function may be used for 
    // inserting new samples into the sample buffer directly. Please be careful
    // not corrupt the book-keeping!
    //
    // When using this function as means for inserting new samples, also remember 
    // to increase the sample count afterwards, by calling  the 
    // 'push(numSamples)' function.
    //
    // 'slackCapacity' - How much free capacity (in samples) there "at least" 
    // should be so that the caller can succesfully insert the desired samples
    // to the buffer. If necessary, the function grows the buffer size to comply
    // with this requirement.
    SampleType *end(size_t slackCapacity);

    // Adds 'numSamples' pcs of samples from the 'samples' memory position to
    // the sample buffer. == sizeof(Type) * numSamples
    void push(const SampleType *samples, size_t numSamples);

    // Adjusts the book-keeping to increase number of samples in the buffer without 
    // copying any actual samples.
    //
    // This function is used to update the number of samples in the sample buffer
    // when accessing the buffer directly with 'end' function. Please be 
    // careful though!
    void push(size_t numSamples);

    // Output samples from beginning of the sample buffer. Copies requested samples to 
    // output buffer and removes them from the sample buffer. If there are less than 
    // 'numsample' samples in the buffer, returns all that available.
    //
    // \return Number of samples returned.
    size_t pop(SampleType *output, size_t maxSamples);

    // Adjusts book-keeping so that given number of samples are removed from beginning of the 
    // sample buffer without copying them anywhere. 
    //
    // Used to reduce the number of samples in the buffer when accessing the sample buffer directly
    // with 'begin' function.
    // \return Actually poped number of samples returned.
    size_t pop(size_t maxSamples);

    // Returns number of samples currently available.
    size_t size() const;

    // Returns nonzero if there aren't any samples available for outputting.
    bool empty() const;

    // Clears all the samples.
    void clear();

    // allow trimming (downwards) amount of samples in pipeline.
    // Returns adjusted amount of samples
    size_t trim(size_t numSamples);

private:
    // Sample buffer.
    SampleType *mBuffer;

    // Raw unaligned buffer memory. 'buffer' is made aligned by pointing it to first
    // 16-byte aligned location of this buffer
    SampleType *mBufferUnaligned;

    // Sample buffer size in bytes
    size_t mSizeInBytes;

    // How many samples are currently in buffer.
    size_t mSamplesInBuffer;

    // Current position pointer to the buffer. This pointer is increased when samples are 
    // removed from the pipe so that it's necessary to actually rewind buffer (move data)
    // only new data when is put to the pipe.
    size_t mBufferPosition;

    // Rewind the buffer by moving data from position pointed by 'mBufferPosition' to real 
    // beginning of the buffer.
    void rewind();

    /// Ensures that the buffer has capacity for at least this many samples.
    void ensureCapacity(size_t capacityRequirement);

    /// Returns current capacity.
    size_t getCapacity() const;
};

#include "FIFOBufferImpl.h"

#endif
