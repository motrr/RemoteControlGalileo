//  Created by Chris Harding on 17/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <QuartzCore/CAEAGLLayer.h>
#import <CoreVideo/CVOpenGLESTextureCache.h>

@interface OnscreenFBO : NSObject
{
    GLuint frameBuffer;
    GLuint renderBuffer;
    
    EAGLContext* oglContext;
    
    int renderBufferWidth;
    int renderBufferHeight;
    
}

- (id) initWithLayer:(CAEAGLLayer *)layer andContext: (EAGLContext*) context;
- (void) render;


@end