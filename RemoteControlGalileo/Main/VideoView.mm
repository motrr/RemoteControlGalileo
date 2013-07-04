//
//  VideoView.m
//  RemoteControlGalileo
//
//  Created by Chris Harding on 30/06/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoView.h"
#import "OnscreenFBO.h"

#include "Buffer.h"
#include "Shader.h"
#include "GLConstants.h"

static unsigned int alignPower2(unsigned int value)
{
    for(int i = 0; i < 32; i++)
    {
        unsigned int c = 1 << i;
        if(value <= c)
            return c;
    }
    return 0;
}

@implementation VideoView

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self != nil)
    {
        // Use 2x scale factor on Retina displays.
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
        self.contentMode = UIViewContentModeScaleAspectFill;
        
        if(![self setupLayer]) NSLog(@"Problem setting up layers");
        if(![self createContext]) NSLog(@"Problem setting up context");
        
        yuv2bgrProgram = new Shader("yuv2bgr.vert", "yuv2bgr.frag");
        yuv2bgrProgram->compile();
        
        memset(yuvTextures, 0, sizeof(GLuint) * 3);
        isFirstRenderCall = YES;
    }
    
    return self;
}

- (void)dealloc
{
    [self destroyYuvTextures];
    delete yuv2bgrProgram;
}

- (void)didDecodeYuvBuffer:(YuvBuffer*)yuvBuffer
{
    // Render the pixel buffer using OpenGL on main thread
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, mainQueue, ^{
        [self renderYuvBuffer:yuvBuffer];
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);
}

- (void)renderYuvBuffer:(YuvBuffer*)yuvBuffer
{    
    // This isn't the only OpenGL ES context
    [EAGLContext setCurrentContext:oglContext];
    
    // Large amount of setup is done on the first call to render, when the pixel buffer dimensions are available
    if(isFirstRenderCall)
    {
        // Now that the context is active and the layer setup, we can create the onscreen buffer
        onscreenFrameBuffer = [[OnscreenFBO alloc] initWithLayer:(CAEAGLLayer *)self.layer
                                                        andContext:oglContext];
        
        // Our rendering target is always the full viewport (either the entire screen or entire destination texture surface)
        glVertexAttribPointer(SA_POSITION, 2, GL_FLOAT, 0, 0, GL::originCentredSquareVertices);
        glEnableVertexAttribArray(SA_POSITION);
        
        yuv2bgrProgram->bind();
        yuv2bgrProgram->setInt1("yPlane", 0);
        yuv2bgrProgram->setInt1("uPlane", 1);
        yuv2bgrProgram->setInt1("vPlane", 2);
        
        isFirstRenderCall = NO;
    }
    
    // We can now create the input texture, which has to be done every frame
    [onscreenFrameBuffer beginRender];
    //glClear(GL_COLOR_BUFFER_BIT);
    
    [self updateAndBindYuvTextures:yuvBuffer];
    
    // Bind the texture vertices to turn off cropping for the displayed image
    glVertexAttribPointer(SA_TEXTURE0, 2, GL_FLOAT, 0, 0, textureUvs);
    glEnableVertexAttribArray(SA_TEXTURE0);
    
    // Render the full video frame to the screen
    yuv2bgrProgram->bind();
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    yuv2bgrProgram->unbind();
    
    // Cleanup input texture
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, 0); // unbind
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, 0); // unbind
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, 0); // unbind
    
    [onscreenFrameBuffer endRender];
    [onscreenFrameBuffer present];
}

#pragma mark
#pragma mark Primary initialisation helper methods

// Force UIView to use the CAEAGLE layer type when creating layer
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (Boolean)setupLayer
{
    // Initialize OpenGL ES 2.0
    CAEAGLLayer* eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                    nil];
    return true;
}

- (Boolean)createContext
{
    // Create the graphics context
    oglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if(!oglContext || ![EAGLContext setCurrentContext:oglContext])
        return false;
    
    glClearColor(1.f, 1.f, 1.f, 1.f);
    glDisable(GL_DITHER);
    glDisable(GL_BLEND);
    glDisable(GL_STENCIL_TEST);
    //glDisable(GL_TEXTURE_2D);
    glDisable(GL_DEPTH_TEST);
    
    return true;
}

#pragma mark
#pragma mark Texture creation

- (void)updateAndBindYuvTextures:(YuvBuffer*)yuvBuffer
{
    // todo: should we use aligned textures?
    // Create texture
    bool shouldAllocate = false;
    if(yuvTextures[0] == 0)
    {
        glGenTextures(3, yuvTextures);
        shouldAllocate = true;
    }
        
    for(int i = 0; i < 3; i++)
    {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, yuvTextures[i]);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        
        unsigned int w = yuvBuffer->getStride(i);
        unsigned int ww = yuvBuffer->getWidth() >> ((i > 0) ? 1 : 0);
        unsigned int h = yuvBuffer->getHeight() >> ((i > 0) ? 1 : 0);
        if(shouldAllocate)
        {
            unsigned int aw = w;//alignPower2(w);
            unsigned int ah = h;//alignPower2(h);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            //glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, aw, ah, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0);
            
            if(i == 0)
            {
                // generate UVs
                float nw = ww < aw ? ww / (float)(aw + 1) : ww / (float)aw;
                float nh = h < ah ? h / (float)(ah + 1) : h / (float)ah;
                
                textureUvs[0] = 0.f;
                textureUvs[1] = 0.f;
                textureUvs[2] = nw;
                textureUvs[3] = 0.f;
                textureUvs[4] = 0.f;
                textureUvs[5] = nh;
                textureUvs[6] = nw;
                textureUvs[7] = nh;
            }
        }
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, w, h, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, yuvBuffer->getPlane(i));
        //glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, w, h, GL_LUMINANCE, GL_UNSIGNED_BYTE, yuvBuffer->planes[i]);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
    }
}

- (void)destroyYuvTextures
{
    if(yuvTextures[0] != 0)
        glDeleteTextures(3, yuvTextures);
}

@end
