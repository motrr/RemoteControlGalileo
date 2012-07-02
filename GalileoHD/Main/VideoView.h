//
//  VideoView.h
//  GalileoHD
//
//  Created by Chris Harding on 30/06/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class OnscreenFBO;


@interface VideoView : UIView
{
    // On screen frame buffer to display frames
    OnscreenFBO* onscreenFrameBuffer;
    
    // Dimensions of the pixel buffer
    size_t pixelBufferWidth; 
    size_t pixelBufferHeight;
    
    // Graphics context
    EAGLContext* oglContext;
    
    // Texture and texture caches for video frames
    CVOpenGLESTextureCacheRef inputTextureCache;
    CVOpenGLESTextureRef inputTexture; // linked to input pixelBuffer  
    
    // Handle to the shader programs
    GLuint passThroughProgram;
    
    Boolean isFirstRenderCall;

}

- (void) renderPixelBuffer:(CVPixelBufferRef)inputPixelBuffer;

@end
