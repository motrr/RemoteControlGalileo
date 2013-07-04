//  Created by Chris Harding on 17/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "OnscreenFBO.h"

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

- (void) present
{
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [oglContext presentRenderbuffer:GL_RENDERBUFFER];
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
}

- (void) dealloc
{
    NSLog(@"OnscreenFBO exiting");
}

@end
