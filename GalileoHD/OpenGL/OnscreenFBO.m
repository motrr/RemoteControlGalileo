//  Created by Chris Harding on 17/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "OnscreenFBO.h"

#import "ShaderUtilities.h"

#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES2/glext.h>


@implementation OnscreenFBO

- (id) initWithLayer:(CAEAGLLayer *)layer andContext: (EAGLContext*) context
{
    self = [super init];
    if (self != nil) {
        
        NSLog(@"Creating OnscreenFBO");
        
        oglContext = context;
        
        // Create and bind the onscreen framebuffer and render buffer
        glGenFramebuffers(1, &frameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
        glGenRenderbuffers(1, &renderBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
        
        // Connect the renderbuffer to the view's layer
        if (![oglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer])
            NSLog(@"Error connecting render buffer to EAGL layer");
        
        // Get the height and width parameters from the render buffer
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &renderBufferWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &renderBufferHeight);
        NSLog(@"Render buffer dimensions %d x %d", renderBufferWidth, renderBufferHeight);
        
        // Connect the render buffer to the framebuffer's colour attachment
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
        
        // Check for successful generation
        if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"Error creating onscreen framebuffer: code %u", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        }
        
    }
    return self;
}

- (void) render
{
    // Bind the framebuffer and render buffer
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    
    // Set the view port to the entire view usind the dimensions
    glViewport(0, 0, renderBufferWidth, renderBufferHeight);

    // Draw the video texture
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    // Present
    [oglContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (void) dealloc
{
    NSLog(@"OnscreenFBO exiting");
}

@end
