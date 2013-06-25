//  Created by Chris Harding on 23/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <QuartzCore/CAEAGLLayer.h>
#import <CoreVideo/CVOpenGLESTextureCache.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES2/glext.h>

#define FRONT_FACING_CAMERA 0
#define REAR_FACING_CAMERA  1

@class Vp8Encoder;
@class PacketSender;
@class OffscreenFBO;

enum TextureType
{
    TT_RGBA,
    TT_LUMA,
    TT_CHROMA
};

// After frames are processed by the GPU we pass the result to a delegate
@protocol OpenGLProcessorOutputDelegate <NSObject>

- (void) handleOutputFrame: (CVPixelBufferRef) outputPixelBuffer;

@end

@interface OpenGLProcessor : NSObject
{
    // Incoming and outgoing pixel buffer
    CVPixelBufferRef outputPixelBuffer;
    //CVPixelBufferRef resizedPixelBuffer;
    //CVPixelBufferRef latestPixelBuffer;
    
    // Offscreen frame buffer
    OffscreenFBO* offscreenFrameBuffer[2];
    
    // Dimensions of the pixel buffer
    size_t inputPixelBufferWidth; 
    size_t inputPixelBufferHeight;
    size_t outputPixelBufferWidth; 
    size_t outputPixelBufferHeight;
    
    // Graphics context
    EAGLContext* oglContext;
    
    // Texture and texture caches for video frames
    CVOpenGLESTextureCacheRef inputTextureCache;
    CVOpenGLESTextureRef inputTexture[2]; // linked to input pixelBuffer
    CVOpenGLESTextureCacheRef outputTextureCache;
    CVOpenGLESTextureRef outputTexture; // linked to output pixelBuffer
    CVOpenGLESTextureRef resizedTexture; // linked to resized pixelBuffer
    
    // Handle to the shader programs
    GLuint yuv2yuvProgram;
    GLuint yPlanarProgram;
    GLuint uPlanarProgram;
    GLuint vPlanarProgram;
    
    // We need to crop video to iOS screen aspect ratio on the way in
    GLfloat cropInputTextureVertices[8]; 
    
    Boolean isFirstRenderCall;
    
}

@property (nonatomic, weak) id<OpenGLProcessorOutputDelegate> outputDelegate;

// Each time the proccessor runs it uses the latest pixel buffer, set by an external thread
//@property CVPixelBufferRef latestPixelBuffer;

@property (nonatomic) unsigned int cameraOrientation;
@property (nonatomic) double zoomFactor;

- (void) processVideoFrameYuv: (CVPixelBufferRef) pixelBuffer;


@end


// Class extension hides private methods
@interface OpenGLProcessor (Private)

// Primary initialisation
- (Boolean) createContext;
- (GLuint) loadShader: (NSString*) name;
- (const GLchar *) readShaderFile: (NSString *) name;
- (Boolean) generateTextureCaches;

// Secondary initialisation, on first render call
- (Boolean) createPixelBuffer: (CVPixelBufferRef*) pixelBuffer_ptr width: (size_t) width height: (size_t) height;
- (void) generatePolygonVertices;
- (void) generateTextureVertices: (GLfloat*) textureVertices;
- (CGRect) textureSamplingRectForCroppingTextureWithAspectRatio:(CGSize)textureAspectRatio
                                                  toAspectRatio:(CGSize)croppingAspectRatio;

// Texture creation (used for input and output texture)
- (CVOpenGLESTextureRef) createTextureLinkedToBuffer: (CVPixelBufferRef) pixelBuffer
                                           withCache: (CVOpenGLESTextureCacheRef) textureCache
                                         textureType: (int)textureType;


@end

