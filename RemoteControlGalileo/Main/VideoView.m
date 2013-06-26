//
//  VideoView.m
//  RemoteControlGalileo
//
//  Created by Chris Harding on 30/06/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoView.h"
#import "ShaderUtilities.h"
#import "OnscreenFBO.h"

static unsigned int alignPower2(unsigned int value)
{
	for(int i = 0; i < 32; i++) {
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
    if (self != nil) {
        
		// Use 2x scale factor on Retina displays.
		self.contentScaleFactor = [[UIScreen mainScreen] scale];
        self.contentMode = UIViewContentModeScaleAspectFill;
        
        if (![self setupLayer]) NSLog(@"Problem setting up layers");
        if (![self createContext]) NSLog(@"Problem setting up context");
        yuv2bgrProgram = [self loadShader:@"yuv2bgr"];
        if (![self generateTextureCaches]) NSLog(@"Problem generating texture cache");
        
        memset(yuvTextures, 0, sizeof(GLuint) * 3);
        isFirstRenderCall = YES;
    }
	
    return self;
}

- (void)dealloc
{
}

- (void) renderYuvBuffer:(YuvBuffer*)yuvBuffer
{
    // This isn't the only OpenGL ES context
    [EAGLContext setCurrentContext:oglContext];
    
    // Large amount of setup is done on the first call to render, when the pixel buffer dimensions are available
    if (isFirstRenderCall) {
        
        // Now that the context is active and the layer setup, we can create the onscreen buffer
        onscreenFrameBuffer = [[OnscreenFBO alloc] initWithLayer: (CAEAGLLayer *) self.layer
                                                        andContext:oglContext];
        
        // Our rendering target is always the full viewport (either the entire screen or entire destination texture surface)
        glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, originCentredSquareVertices);
        glEnableVertexAttribArray(ATTRIB_VERTEX);
        
        GLint location1 = glueGetUniformLocation(yuv2bgrProgram, "yPlane");
        GLint location2 = glueGetUniformLocation(yuv2bgrProgram, "uPlane");
        GLint location3 = glueGetUniformLocation(yuv2bgrProgram, "vPlane");
        glUseProgram(yuv2bgrProgram);
        glUniform1i(location1, 0);
        glUniform1i(location2, 1);
        glUniform1i(location3, 2);
        
        isFirstRenderCall = NO;
    }
    
    // We can now create the input texture, which has to be done every frame
    [onscreenFrameBuffer beginRender];
    //glClear(GL_COLOR_BUFFER_BIT);
    
    [self updateAndBindYuvTextures:yuvBuffer];
    /*glActiveTexture(GL_TEXTURE0);
    inputTexture[0] = [self createTextureLinkedToBuffer:yuvBuffer->buffers[0] withCache:inputTextureCache planeIndex:0];
    glActiveTexture(GL_TEXTURE1);
    inputTexture[1] = [self createTextureLinkedToBuffer:yuvBuffer->buffers[0] withCache:inputTextureCache planeIndex:0];
    glActiveTexture(GL_TEXTURE2);
    inputTexture[2] = [self createTextureLinkedToBuffer:yuvBuffer->buffers[0] withCache:inputTextureCache planeIndex:0];//*/
    
    // Bind the texture vertices to turn off cropping for the displayed image
    glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, textureUvs);//unitSquareVertices);
    glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);
    
    // Render the full video frame to the screen
    glUseProgram(yuv2bgrProgram);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    // Cleanup input texture
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, 0); // unbind
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, 0); // unbind
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, 0); // unbind
    
    [onscreenFrameBuffer endRender];
    [onscreenFrameBuffer present];
    
    /*CVOpenGLESTextureCacheFlush(inputTextureCache, 0);
    CFRelease(inputTexture[0]);
    CFRelease(inputTexture[1]);
    CFRelease(inputTexture[2]);//*/
}

#pragma mark
#pragma mark Primary initialisation helper methods

// Force UIView to use the CAEAGLE layer type when creating layer
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (Boolean) setupLayer
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

- (Boolean) createContext
{
    // Create the graphics context
    oglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!oglContext || ![EAGLContext setCurrentContext:oglContext])
        return false;
    else
        return true;
        
    glClearColor(1.f, 1.f, 1.f, 1.f);
    glDisable(GL_DITHER);
    glDisable(GL_BLEND);
    glDisable(GL_STENCIL_TEST);
    //glDisable(GL_TEXTURE_2D);
    glDisable(GL_DEPTH_TEST);
}

- (GLuint) loadShader: (NSString*) name
{
    GLuint program;
    
    // Load vertex and fragment shaders
    const GLchar *vertSrc = [self readShaderFile: [name stringByAppendingString:@".vert"]];
    const GLchar *fragSrc = [self readShaderFile: [name stringByAppendingString:@".frag"]];
    
    // Configure shader attributes
    GLint attribLocation[NUM_ATTRIBUTES] = {
        ATTRIB_VERTEX, ATTRIB_TEXTUREPOSITON,
    };
    GLchar *attribName[NUM_ATTRIBUTES] = {
        "position", "textureCoordinate",
    };
    
    // Create the shader program
    glueCreateProgram(vertSrc, fragSrc,
                      NUM_ATTRIBUTES, (const GLchar **)&attribName[0], attribLocation,
                      0, 0, 0, // we don't need to get uniform locations for now
                      &program);
    
    // Check creation was successful
    if (!program)
        NSLog(@"Error creating shader %@", name);
    
    
    return program;
}

- (const GLchar *) readShaderFile: (NSString *) name
{
    NSString *path;
    const GLchar *source;
    
    path = [[NSBundle mainBundle] pathForResource:name ofType: nil];
    source = (GLchar *)[[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] UTF8String];
    
    return source;
}

- (Boolean) generateTextureCaches
{
    CVReturn err;
    
    //  Create a new video input texture cache
    err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, (__bridge CVEAGLContext)((__bridge void *)(oglContext)), NULL, &inputTextureCache);
    if (err) {
        NSLog(@"Error creating input texture cache with CVReturn error %u", err);
        return false;
    }
    
    if (inputTextureCache == NULL) {
        NSLog(@"One or more texture caches are null");
        return false;
    }
    
    return true;
}

#pragma mark
#pragma mark Texture creation

- (CVOpenGLESTextureRef) createTextureLinkedToBuffer: (CVPixelBufferRef) pixelBuffer
                                           withCache: (CVOpenGLESTextureCacheRef) textureCache
                                          planeIndex: (size_t)planeIndex
{
    CVOpenGLESTextureRef texture = NULL;
    CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                textureCache,
                                                                pixelBuffer,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                GL_LUMINANCE,
                                                                CVPixelBufferGetWidth(pixelBuffer),
                                                                CVPixelBufferGetHeight(pixelBuffer),
                                                                GL_LUMINANCE,
                                                                GL_UNSIGNED_BYTE,
                                                                planeIndex,
                                                                &texture);
    
    if (!texture || err) {
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);
    }
    
    // Set texture parameters
	glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    return texture;
}

- (void) updateAndBindYuvTextures:(YuvBuffer*)yuvBuffer
{
    // todo: should we use aligned textures?
    // Create texture
    bool shouldAllocate = false;
    if(yuvTextures[0] == 0) {
        glGenTextures(3, yuvTextures);
        shouldAllocate = true;
    }
        
    for(int i = 0; i < 3; i++) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, yuvTextures[i]);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        
        unsigned int w = yuvBuffer->stride[i];
        unsigned int ww = yuvBuffer->width >> ((i > 0) ? 1 : 0);
        unsigned int h = yuvBuffer->height >> ((i > 0) ? 1 : 0);
        if(shouldAllocate) {
            unsigned int aw = w;//alignPower2(w);
            unsigned int ah = h;//alignPower2(h);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            //glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, aw, ah, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0);
            
            if(i == 0) {
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
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, w, h, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, yuvBuffer->planes[i]);
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
