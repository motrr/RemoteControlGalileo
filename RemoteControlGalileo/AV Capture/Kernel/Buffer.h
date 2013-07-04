#ifndef Buffer_H
#define Buffer_H

#include <stddef.h>
#include <assert.h>
#include <memory>

class Buffer
{
public:
    virtual ~Buffer() {}
    virtual void *getData() const = 0;
    virtual size_t getSize() const = 0;
};

class WrapBuffer : public Buffer
{
public:
    WrapBuffer(void *buffer, size_t size): mBuffer(buffer), mSize(size) {}
    virtual ~WrapBuffer() {}
    
    virtual void *getData() const { return mBuffer; }
    virtual size_t getSize() const { return mSize; }
    
private:
    void *mBuffer;
    size_t mSize; // size in bytes
};

// YV12
class YuvBuffer : public Buffer
{
public:
    virtual ~YuvBuffer() {}
    virtual void *getPlane(size_t index) const = 0;
    virtual size_t getStride(size_t index) const = 0;
    virtual size_t getWidth() const = 0;
    virtual size_t getHeight() const = 0;
};

class YuvWrapBuffer : public YuvBuffer
{
public:
    YuvWrapBuffer(size_t width, size_t height, void *planes[3], size_t stride[3], size_t size): 
    mWidth(width), mHeight(height), mSize(size) 
    {
        // todo: memcpy
        mPlanes[0] = planes[0];
        mPlanes[1] = planes[1];
        mPlanes[2] = planes[2];
        
        mStride[0] = stride[0];
        mStride[1] = stride[1];
        mStride[2] = stride[2];
    }
    virtual ~YuvWrapBuffer() {}
    
    virtual void *getData() const { return mPlanes[0]; }
    virtual size_t getSize() const { return mSize; }
    
    virtual void *getPlane(size_t index) const { assert(index < 3); return mPlanes[index]; }
    virtual size_t getStride(size_t index) const { assert(index < 3); return mStride[index]; }
    virtual size_t getWidth() const { return mWidth; }
    virtual size_t getHeight() const { return mHeight; }
    
private:
    void *mPlanes[3];
    size_t mStride[3];
    size_t mSize;

    size_t mWidth;
    size_t mHeight;
};

#if __cplusplus <= 199711L
    // older C++ version
    typedef std::auto_ptr<Buffer> BufferPtr;
    typedef std::auto_ptr<YuvBuffer> YuvBufferPtr;
#elif
    // C++11
    typedef std::unique_ptr<Buffer> BufferPtr;
    typedef std::unique_ptr<YuvBuffer> YuvBufferPtr;
#endif

#endif