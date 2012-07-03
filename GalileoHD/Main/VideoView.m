//
//  VideoView.m
//  GalileoHD
//
//  Created by Chris Harding on 30/06/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "VideoView.h"
#import "ShaderUtilities.h"
#import "OnscreenFBO.h"

@implementation VideoView

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil) {
        
		// Use 2x scale factor on Retina displays.
		self.contentScaleFactor = [[UIScreen mainScreen] scale];
        
        if (![self setupLayer]) NSLog(@"Problem setting up layers");
        if (![self createContext]) NSLog(@"Problem setting up context");
        passThroughProgram = [self loadShader:@"passThrough"];
        if (![self generateTextureCaches]) NSLog(@"Problem generating texture cache");
        
        isFirstRenderCall = YES;
    }
	
    return self;
}

- (void) renderPixelBuffer:(CVPixelBufferRef)inputPixelBuffer
{
    // This isn't the only OpenGL ES context
    [EAGLContext setCurrentContext:oglContext];
    
    // Large amount of setup is done on the first call to render, when the pixel buffer dimensions are available
    if (isFirstRenderCall) {
        
        // Now that the context is active and the layer setup, we can create the onscreen buffer
        onscreenFrameBuffer = [[OnscreenFBO alloc] initWithLayer: (CAEAGLLayer *) self.layer
                                                        andContext:oglContext];
        
        // Record the dimensions of the pixel buffer (we assume they won't change from now on)
        pixelBufferWidth = CVPixelBufferGetWidth(inputPixelBuffer);
        pixelBufferHeight = CVPixelBufferGetHeight(inputPixelBuffer);
        NSLog(@"Pixel buffer dimensions %zu x %zu", pixelBufferWidth, pixelBufferHeight);
        
        // Our rendering target is always the full viewport (either the entire screen or entire destination texture surface)
        glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, originCentredSquareVertices);
        glEnableVertexAttribArray(ATTRIB_VERTEX);
        
        isFirstRenderCall = NO;
    }
    
    // We can now create the input texture, which has to be done every frame
    inputTexture = [self createTextureLinkedToBuffer:inputPixelBuffer withCache:inputTextureCache];
    
    // Bind the texture vertices to turn off cropping for the displayed image
    glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, unitSquareVertices);
    glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);
    glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);
    
    // Render the full video frame to the screen
    glUseProgram(passThroughProgram);
    [onscreenFrameBuffer render]; // will set viewport itself
    
    // Cleanup input texture
    glBindTexture(CVOpenGLESTextureGetTarget(inputTexture), 0); // unbind
    CVOpenGLESTextureCacheFlush(inputTextureCache, 0);
    CFRelease(inputTexture);
    
    // Cleanup pixel buffer
    CVPixelBufferRelease(inputPixelBuffer);
    
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
    err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, oglContext, NULL, &inputTextureCache);
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
{
    CVOpenGLESTextureRef texture = NULL;
    CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                textureCache,
                                                                pixelBuffer,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                GL_RGBA,
                                                                pixelBufferWidth,
                                                                pixelBufferHeight,
                                                                GL_BGRA,
                                                                GL_UNSIGNED_BYTE,
                                                                0,
                                                                &texture);
    
    if (!texture || err) {
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);
    }
    
    // Set texture parameters
	glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    return texture;
}

@end
