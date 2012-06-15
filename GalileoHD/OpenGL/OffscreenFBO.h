//  Created by Chris Harding on 17/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreVideo/CVOpenGLESTextureCache.h>


@interface OffscreenFBO : NSObject
{
    GLuint frameBuffer;
}

- (id) initWithTexture: (CVOpenGLESTextureRef) texture;
- (void) render;

@end
