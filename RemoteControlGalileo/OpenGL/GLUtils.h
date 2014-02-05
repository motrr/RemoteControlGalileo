#ifndef GLUtils_h
#define GLUtils_h

#include <CoreGraphics/CGGeometry.h>

namespace GL
{
    enum ContentMode
    {
        CM_SCALE_TO_FILL,
        CM_SCALE_ASPECT_TO_FIT, // todo: not supported, we have to adjust positions for this as well as UVs
        CM_SCALE_ASPECT_TO_FILL,
    };
    
    void calculateUVs(ContentMode mode, float sourceAspect, float targetAspect, 
                      float zoomFactor, float *uvs, float normWidth = 1.f, float normHeight = 1.f);
    void rotateUVs90(float *uvs); // not actual rotate, e.g. using two times wont rotate 180 deg :)
    void flipHorizontally(float *uvs);
}

#endif
