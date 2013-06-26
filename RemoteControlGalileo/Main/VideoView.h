//
//  VideoView.h
//  RemoteControlGalileo
//
//  Created by Chris Harding on 30/06/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoDecoder.h"

@class OnscreenFBO;

@interface VideoView : UIView
{
    // On screen frame buffer to display frames
    OnscreenFBO* onscreenFrameBuffer;
    
    // Graphics context
    EAGLContext* oglContext;
    
    // Texture and texture caches for video frames
    CVOpenGLESTextureCacheRef inputTextureCache;
    CVOpenGLESTextureRef inputTexture[3]; // linked to input pixelBuffer  
    
    // Handle to the shader programs
    GLuint yuv2bgrProgram;
    
    // Texture handles
    GLuint yuvTextures[3]; // YUV
    GLfloat textureUvs[8];
    
    Boolean isFirstRenderCall;

}

- (void) renderYuvBuffer:(YuvBuffer*)yuvBuffer;

@end
