//  Created by Chris Harding on 23/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>

#include "VideoTxRxCommon.h"

@class OffscreenFBO;
class Shader;

enum TextureType
{
    TT_RGBA,
    TT_LUMA,
    TT_CHROMA
};

// After frames are processed by the GPU we pass the result to a delegate
@protocol OpenGLProcessorDelegate

- (void)didProcessFrame:(CVPixelBufferRef)pixelBuffer;

@end

@interface OpenGLProcessor : NSObject
{
    // Incoming and outgoing pixel buffer
    CVPixelBufferRef outputPixelBuffer;
    
    // Offscreen frame buffer
    OffscreenFBO *offscreenFrameBuffer[2];
    
    // Dimensions of the pixel buffer
    size_t inputPixelBufferWidth; 
    size_t inputPixelBufferHeight;
    size_t outputPixelBufferWidth; 
    size_t outputPixelBufferHeight;
    
    // Graphics context
    EAGLContext *oglContext;
    
    // Texture and texture caches for video frames
    CVOpenGLESTextureCacheRef inputTextureCache;
    CVOpenGLESTextureRef inputTexture[2]; // linked to input pixelBuffer
    CVOpenGLESTextureCacheRef outputTextureCache;
    CVOpenGLESTextureRef outputTexture; // linked to output pixelBuffer
    CVOpenGLESTextureRef resizedTexture; // linked to resized pixelBuffer
    
    // Handle to the shader programs
    Shader *yuv2yuvProgram;
#ifndef USE_SINGLE_PASS_PREPROCESS
    Shader *yPlanarProgram;
    Shader *uPlanarProgram;
    Shader *vPlanarProgram;
#endif
    
    // We need to crop video to iOS screen aspect ratio on the way in
    GLfloat cropInputTextureVertices[8]; 
    
    Boolean isFirstRenderCall;
}

@property(nonatomic, weak) id delegate;
@property(nonatomic) unsigned int cameraOrientation;
@property(nonatomic) double zoomFactor;

- (void)setOutputWidth:(int)width height:(int)height;
- (void)processVideoFrameYuv:(CVPixelBufferRef)pixelBuffer;

@end


// Class extension hides private methods
@interface OpenGLProcessor (Private)

// Primary initialisation
- (Boolean)createContext;
- (Boolean)generateTextureCaches;

// Secondary initialisation, on first render call
- (Boolean)createPixelBuffer:(CVPixelBufferRef*)pixelBufferPtr width:(size_t)width height:(size_t)height;

// Texture creation (used for input and output texture)
- (CVOpenGLESTextureRef)createTextureLinkedToBuffer:(CVPixelBufferRef)pixelBuffer
                                          withCache:(CVOpenGLESTextureCacheRef)textureCache
                                        textureType:(int)textureType;


@end

