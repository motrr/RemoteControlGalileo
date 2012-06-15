//  Created by Chris Harding on 23/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ShaderUtilities.h"

#import <QuartzCore/CAEAGLLayer.h>
#import <CoreVideo/CVOpenGLESTextureCache.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES2/glext.h>

#define FRONT_FACING_CAMERA 0
#define REAR_FACING_CAMERA  1

@class VideoTransmitter;
@class OffscreenFBO;

@interface VideoProcessor : NSObject
{
    // Transmitter to whom we send out frames
    VideoTransmitter* videoTransmitter;
    
    // Incoming and outgoing pixel buffer
    CVPixelBufferRef inputPixelBuffer;
    CVPixelBufferRef outputPixelBuffer;
    CVPixelBufferRef latestPixelBuffer;
    
    // Offscreen frame buffer
    OffscreenFBO* offscreenFrameBuffer;
    
    // Dimensions of the pixel buffer
    size_t inputPixelBufferWidth; 
    size_t inputPixelBufferHeight;
    size_t outputPixelBufferWidth; 
    size_t outputPixelBufferHeight;
    
    // Graphics context
    EAGLContext* oglContext;
    
    // Texture and texture caches for video frames
    CVOpenGLESTextureCacheRef inputTextureCache;
    CVOpenGLESTextureRef inputTexture; // linked to input pixelBuffer
    //
    CVOpenGLESTextureCacheRef outputTextureCache;
    CVOpenGLESTextureRef outputTexture; // linked to output pixelBuffer    
    
    // Handle to the shader programs
    GLuint passThroughProgram;
    
    Boolean isFirstRenderCall;
    
    // We need to crop video to iOS screen aspect ratio on the way in
    GLfloat cropInputTextureVertices[8]; 
    
}

// Each time the proccessor runs it uses the latest pixel buffer, set by an external thread
@property CVPixelBufferRef latestPixelBuffer;

@property (nonatomic) unsigned int cameraOrientation;
@property (nonatomic) double zoomFactor;

- (id) initWithTransmitter: (VideoTransmitter*) initVideoTransmitter;
- (void) processVideoFrame;


@end


// Class extension hides private methods
@interface VideoProcessor (private)

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
                                           withCache: (CVOpenGLESTextureCacheRef) textureCache;


@end

