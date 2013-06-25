//  Created by Chris Harding on 17/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "OffscreenFBO.h"

@implementation OffscreenFBO

- (id) initWithWidth: (int) width height: (int) height
{
    self = [super init];
    if (self != nil) {
        
        NSLog(@"Creating OffscreenFBO");
        
        glGenTextures(1, &texture);
        glGenFramebuffers(1, &frameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
        
        renderBufferWidth = width;
        renderBufferHeight = height;
        
        // create render buffer
        bool needAlpha = true;
        GLint format = needAlpha ? GL_RGBA : GL_RGB;
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, GL_UNSIGNED_BYTE, NULL);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
            
        const GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);  
        if(status != GL_FRAMEBUFFER_COMPLETE) {
            printf("Frame buffer was not created successfully!"); 
        }
    }
    return self;
}

- (id) initWithTexture:(CVOpenGLESTextureRef)textureRef width:(int)width height:(int)height
{
    self = [super init];
    if (self != nil) {
        
        NSLog(@"Creating OffscreenFBO");
        
        // Create and bind the offscreen framebuffer
        glGenFramebuffers(1, &frameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
        
        renderBufferWidth = width;
        renderBufferHeight = height;
        
        // Connect the output texture to the framebuffer's colour attachment
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_2D, CVOpenGLESTextureGetName(textureRef), 0);
        
        // Check for successful generation
        if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            
            NSLog(@"Error creating offscreen framebuffer");
            
        }
        
    }
    return self;
}

- (void) beginRender
{
    // Bind the framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    
    // Set the view port to the entire view usind the dimensions
    glViewport(0, 0, renderBufferWidth, renderBufferHeight);
}

- (void) endRender
{
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

- (void) bindTexture
{
    glBindTexture(GL_TEXTURE_2D, texture);
}

- (void) dealloc
{
    NSLog(@"OffscreenFBO exiting");
}


@end
