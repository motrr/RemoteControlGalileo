//
//  VideoView.h
//  RemoteControlGalileo
//
//  Created by Chris Harding on 30/06/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>

class Shader;
@class OnscreenFBO;
@interface VideoView : UIView
{
    // On screen frame buffer to display frames
    OnscreenFBO *onscreenFrameBuffer;
    
    // Graphics context
    EAGLContext *oglContext;
    
    // Handle to the shader programs
    Shader *yuv2bgrProgram;
    
    // Texture handles
    GLuint yuvTextures[3]; // YUV
    GLfloat textureUvs[8];
    
    Boolean isFirstRenderCall;
}

@end
