//  Created by Chris Harding on 17/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreVideo/CVOpenGLESTextureCache.h>


@interface OffscreenFBO : NSObject
{
    GLuint texture;
    GLuint frameBuffer;
    
    int renderBufferWidth;
    int renderBufferHeight;
}

- (id) initWithWidth: (int) width height: (int) height;
- (id) initWithTexture: (CVOpenGLESTextureRef) texture width: (int) width height: (int) height;

- (void) beginRender;
- (void) endRender;

- (void) bindTexture;

@end
