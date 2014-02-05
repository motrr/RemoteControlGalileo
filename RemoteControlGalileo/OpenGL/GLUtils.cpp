#include "GLUtils.h"
#include <algorithm>

namespace GL
{

void calculateUVs(ContentMode mode, float sourceAspect, float targetAspect,
                  float zoomFactor, float *uvs, float normWidth, float normHeight)
{
    float width, height;
    if(mode == CM_SCALE_TO_FILL)
    {
        width = height = 1.f;
    }
    else
    {
        // calculate normalized width/height
        if((mode == CM_SCALE_ASPECT_TO_FIT && sourceAspect > targetAspect) ||
            (mode == CM_SCALE_ASPECT_TO_FILL && sourceAspect < targetAspect))
        {
            width = 1.f;
            height = sourceAspect / targetAspect;
        }
        else
        {
            height = 1.f;
            width = targetAspect / sourceAspect;
        }
        
        // normalize
        float maxSize = std::max(width, height);
        width = width * normWidth / maxSize;
        height = height * normHeight / maxSize;
    }
    
    // apply zoom, todo: add support for zoom factor < 1
    width /= zoomFactor;
    height /= zoomFactor;
    
    // calculate offset
    float x = (normWidth - width) * 0.5f;
    float y = (normHeight - height) * 0.5f;

    uvs[0] = x;
    uvs[1] = y;
    //
    uvs[2] = x + width;
    uvs[3] = y;
    //
    uvs[4] = x;
    uvs[5] = y + height;
    //
    uvs[6] = x + width;
    uvs[7] = y + height;
}

void rotateUVs90(float *uvs)
{
    std::swap(uvs[0], uvs[6]);
    std::swap(uvs[1], uvs[7]);
}

void flipHorizontally(float *uvs)
{
    std::swap(uvs[0], uvs[2]);
    std::swap(uvs[4], uvs[6]);
}

}