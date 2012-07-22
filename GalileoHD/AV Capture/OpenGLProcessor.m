//  Created by Chris Harding on 23/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "OpenGLProcessor.h"
#import "Vp8Encoder.h"
#import "PacketSender.h"
#import "OffscreenFBO.h"

#define JPEG_QUALITY_FACTOR     0.9

@implementation OpenGLProcessor

@synthesize cameraOrientation;
@synthesize zoomFactor;

- (CVPixelBufferRef) latestPixelBuffer
{
    return latestPixelBuffer;
}

- (void) setLatestPixelBuffer: (CVPixelBufferRef) latestPixelBuffer_
{
    @synchronized (self) {
        CVPixelBufferRelease(latestPixelBuffer);
        latestPixelBuffer = latestPixelBuffer_;
        CVPixelBufferRetain(latestPixelBuffer);
    }
}


- (id) init
{
    if (self = [super init]) {
        
        zoomFactor = 1.0;
        
        if (![self createContext]) NSLog(@"Problem setting up context");
        passThroughProgram = [self loadShader:@"passThrough"];
        if (![self generateTextureCaches]) NSLog(@"Problem generating texture cache");
        
        isFirstRenderCall = YES;
    }
	
    return self;
}

-(void) dealloc
{
    NSLog(@"VideoProcessor exiting");
}

- (void) processVideoFrame
{

    @synchronized (self) {
        
        // Make sure we process the latest frame available
        inputPixelBuffer = self.latestPixelBuffer;
        CVPixelBufferRetain(inputPixelBuffer);
        
    }

    // This isn't the only OpenGL ES context
    [EAGLContext setCurrentContext:oglContext];
    
    // Large amount of setup is done on the first call to render, when the pixel buffer dimensions are available
    if (isFirstRenderCall) {
        
        // Record the dimensions of the pixel buffer (we assume they won't change from now on)
        inputPixelBufferWidth = CVPixelBufferGetWidth(inputPixelBuffer);
        inputPixelBufferHeight = CVPixelBufferGetHeight(inputPixelBuffer);
        NSLog(@"Input pixel buffer dimensions %zu x %zu", inputPixelBufferWidth, inputPixelBufferHeight);
        
        // We set the output dimensions at a nice iPhone/iPad friendly aspect ratio
        outputPixelBufferWidth = VIDEO_WIDTH;
        outputPixelBufferHeight = VIDEO_HEIGHT;
        
        // These calls use the pixel buffer dimensions
        [self createPixelBuffer:&outputPixelBuffer width:outputPixelBufferWidth height:outputPixelBufferHeight];
        [self generateTextureVertices:cropInputTextureVertices];
        
        // Our rendering target is always the full viewport (either the entire screen or entire destination texture surface)
        glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, originCentredSquareVertices);
        glEnableVertexAttribArray(ATTRIB_VERTEX);
        
        // We can now create the output texture, which only need to be done once (whereas the input texture must be created once per frame)
        outputTexture = [self createTextureLinkedToBuffer:outputPixelBuffer withCache:outputTextureCache];
        
        // With their respective textures we can now create the two offscreen buffers
        offscreenFrameBuffer = [[OffscreenFBO alloc] initWithTexture:outputTexture];
        
        isFirstRenderCall = NO;
    }
    
    // We can now create the input texture, which has to be done every frame
    inputTexture = [self createTextureLinkedToBuffer:inputPixelBuffer withCache:inputTextureCache];
    
    // We also need to recalculate texture vertices in case the zoom level has changed
    [self generateTextureVertices:cropInputTextureVertices];
    
    // Bind the input texture containing a new video frame, ensuring the texture vertices crop the input
    glBindTexture(CVOpenGLESTextureGetTarget(inputTexture), CVOpenGLESTextureGetName(inputTexture));
    glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, cropInputTextureVertices);
    glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);
    
    // Render video frame offscreen to the FBO
    glViewport(0, 0, outputPixelBufferWidth, outputPixelBufferHeight);
    glUseProgram(passThroughProgram);
    [offscreenFrameBuffer render];

    // Cleanup input texture
    glBindTexture(CVOpenGLESTextureGetTarget(inputTexture), 0); // unbind   
    CVOpenGLESTextureCacheFlush(inputTextureCache, 0);
    CFRelease(inputTexture);
    
    // Process using delegate
    //[NSThread detachNewThreadSelector:@selector(handleOutputFrame:) toTarget:self.outputDelegate withObject:(__bridge id)(outputPixelBuffer)];
    [self.outputDelegate handleOutputFrame:outputPixelBuffer];
    
    // Cleanup output texture (but do not release)
    glBindTexture(CVOpenGLESTextureGetTarget(outputTexture), 0); // unbind
    CVOpenGLESTextureCacheFlush(outputTextureCache, 0);
    
    // Release the input pixel buffer
    @synchronized (self) {
        CVPixelBufferRelease(inputPixelBuffer);
    }
    
}


#pragma mark
#pragma mark Primary initialisation helper methods

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
    err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, (__bridge CVEAGLContext)((__bridge void*)oglContext), NULL, &inputTextureCache);
    if (err) {
        NSLog(@"Error creating input texture cache with CVReturn error %u", err);
        return false;
    }
    //  Create a new video output texture cache
    err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, (__bridge CVEAGLContext)((__bridge void*)oglContext), NULL, &outputTextureCache);
    if (err) {
        NSLog(@"Error creating output texture cache with CVReturn error %u", err);
        return false;
    }
    
    if (inputTextureCache == NULL || outputTextureCache == NULL) {
        NSLog(@"One or more texture caches are null");
        return false; 
    }
    
    return true;
}

#pragma mark 
#pragma mark Secondary initialisation helper methods
// Performed on reciept of the first frame

- (Boolean) createPixelBuffer: (CVPixelBufferRef*) pixelBuffer_ptr width: (size_t) width height: (size_t) height
{
    // Define the output pixel buffer attibutes
    CFDictionaryRef emptyValue = CFDictionaryCreate(kCFAllocatorDefault, // our empty IOSurface properties dictionary
                                                    NULL,
                                                    NULL,
                                                    0,
                                                    &kCFTypeDictionaryKeyCallBacks,
                                                    &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef pixelBufferAttributes = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                             1,
                                                                             &kCFTypeDictionaryKeyCallBacks,
                                                                             &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(pixelBufferAttributes, kCVPixelBufferIOSurfacePropertiesKey, emptyValue);
    
    // Create the pixel buffer
    CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                       kCVPixelFormatType_32BGRA,
                                       pixelBufferAttributes,
                                       pixelBuffer_ptr);
    CFRelease(emptyValue);
    CFRelease(pixelBufferAttributes);
    
    // Check for success
    if (err) {
        NSLog(@"Error creating output pixel buffer with CVReturn error %u", err);
        return false;
    }
    
    return true;
}

- (void) generateTextureVertices: (GLfloat*) textureVertices
{
    CGRect textureSamplingRect =
    [self textureSamplingRectForCroppingTextureWithAspectRatio:
        CGSizeMake(inputPixelBufferWidth, inputPixelBufferHeight)
          toAspectRatio:
        CGSizeMake(outputPixelBufferWidth, outputPixelBufferHeight)];

    CGSize newSize = textureSamplingRect.size;
    CGSize oldSize = textureSamplingRect.size;
    newSize.width *= zoomFactor;
    newSize.height *= zoomFactor;
    textureSamplingRect.origin.x += (oldSize.width - newSize.width) / 2;
    textureSamplingRect.origin.y += (oldSize.height - newSize.height) / 2;
    textureSamplingRect.size = newSize;

    textureVertices[0] = CGRectGetMaxX(textureSamplingRect);
    textureVertices[1] = CGRectGetMaxY(textureSamplingRect);
    //
    textureVertices[2] = CGRectGetMaxX(textureSamplingRect);
    textureVertices[3] = CGRectGetMinY(textureSamplingRect);
    //
    textureVertices[4] = CGRectGetMinX(textureSamplingRect);
    textureVertices[5] = CGRectGetMaxY(textureSamplingRect);
    //
    textureVertices[6] = CGRectGetMinX(textureSamplingRect);
    textureVertices[7] = CGRectGetMinY(textureSamplingRect);
}

- (CGRect)textureSamplingRectForCroppingTextureWithAspectRatio:(CGSize)textureAspectRatio toAspectRatio:(CGSize)croppingAspectRatio
{
	CGRect normalizedSamplingRect = CGRectZero;	
	CGSize cropScaleAmount = CGSizeMake(croppingAspectRatio.width / textureAspectRatio.width, croppingAspectRatio.height / textureAspectRatio.height);
	CGFloat maxScale = fmax(cropScaleAmount.width, cropScaleAmount.height);
	CGSize scaledTextureSize = CGSizeMake(textureAspectRatio.width * maxScale, textureAspectRatio.height * maxScale);
	
	if ( cropScaleAmount.height > cropScaleAmount.width ) {
		normalizedSamplingRect.size.width = croppingAspectRatio.width / scaledTextureSize.width;
		normalizedSamplingRect.size.height = 1.0;
	}
	else {
		normalizedSamplingRect.size.height = croppingAspectRatio.height / scaledTextureSize.height;
		normalizedSamplingRect.size.width = 1.0;
	}
	// Center crop
	normalizedSamplingRect.origin.x = (1.0 - normalizedSamplingRect.size.width)/2.0;
	normalizedSamplingRect.origin.y = (1.0 - normalizedSamplingRect.size.height)/2.0;
	
	return normalizedSamplingRect;
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
                                                                CVPixelBufferGetWidth(pixelBuffer),
                                                                CVPixelBufferGetHeight(pixelBuffer),
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
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    return texture;
}


@end
