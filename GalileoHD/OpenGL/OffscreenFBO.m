//  Created by Chris Harding on 17/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "OffscreenFBO.h"

@implementation OffscreenFBO

- (id) initWithTexture:(CVOpenGLESTextureRef)texture
{
    self = [super init];
    if (self != nil) {
        
        // Create and bind the offscreen framebuffer
        glGenFramebuffers(1, &frameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
        
        
        // Connect the output texture to the framebuffer's colour attachment
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_2D, CVOpenGLESTextureGetName(texture), 0);
        
        // Check for successful generation
        if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            
            NSLog(@"Error creating offscreen framebuffer");
            
        }
        
    }
    return self;
}

- (void) render
{
    // Bind the offscreen framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    
    // Draw the output video texture
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}


@end
