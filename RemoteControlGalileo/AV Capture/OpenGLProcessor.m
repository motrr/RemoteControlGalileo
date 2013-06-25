//  Created by Chris Harding on 23/04/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "OpenGLProcessor.h"
#import "Vp8Encoder.h"
#import "PacketSender.h"
#import "OffscreenFBO.h"

#import "ShaderUtilities.h"

GLfloat yPlaneUVs[8] = {
    0.0f, 0.0f,
    1.0f, 0.0f,
    0.0f, 0.3f,
    1.0f, 0.3f
};

GLfloat yPlaneVertices[8] = {
    -1.0f, -1.0f,
     1.0f, -1.0f,
    -1.0f, -0.4f,
     1.0f, -0.4f
};

GLfloat uvPlaneUVs[8] = {
    0.0f, 0.0f,
    1.0f, 0.0f,
    0.0f, 0.1f,
    1.0f, 0.1f
};

GLfloat uPlaneVertices[8] = {
    -1.0f, -0.4f,
     1.0f, -0.4f,
    -1.0f, -0.2f,
     1.0f, -0.2f
};

GLfloat vPlaneVertices[8] = {
    -1.0f, -0.2f,
     1.0f, -0.2f,
    -1.0f,  0.0f,
     1.0f,  0.0f
};

#define JPEG_QUALITY_FACTOR     0.9

@implementation OpenGLProcessor

@synthesize cameraOrientation;
@synthesize zoomFactor;

- (id) init
{
    if (self = [super init]) {
        
        zoomFactor = 1.0;
        
        if (![self createContext]) NSLog(@"Problem setting up context");
        yuv2yuvProgram = [self loadShader:@"yuv2yuv"];
        yPlanarProgram = [self loadShader:@"y2planar"];
        uPlanarProgram = [self loadShader:@"u2planar"];
        vPlanarProgram = [self loadShader:@"v2planar"];
        if (![self generateTextureCaches]) NSLog(@"Problem generating texture cache");
        
        inputTexture[0] = NULL;
        inputTexture[1] = NULL;
        
        isFirstRenderCall = YES;
    }
	
    return self;
}

-(void) dealloc
{
    NSLog(@"VideoProcessor exiting");
}

- (void) processVideoFrameYuv: (CVPixelBufferRef) inputPixelBuffer
{
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
        NSLog(@"Output pixel buffer dimensions %zu x %zu", outputPixelBufferWidth, outputPixelBufferHeight);
        
        // These calls use the pixel buffer dimensions
        [self createPixelBuffer:&outputPixelBuffer width:outputPixelBufferWidth height:outputPixelBufferHeight];
        
        // We can now create the output texture, which only need to be done once (whereas the input texture must be created once per frame)
        outputTexture = [self createTextureLinkedToBuffer:outputPixelBuffer withCache:outputTextureCache textureType:TT_RGBA];
        
        // With their respective textures we can now create the two offscreen buffers
        offscreenFrameBuffer[0] = [[OffscreenFBO alloc] initWithTexture:outputTexture 
                                                                  width:outputPixelBufferWidth height:outputPixelBufferHeight];//*/
        
        // Create intermediate texture with resize data
        offscreenFrameBuffer[1] = [[OffscreenFBO alloc] initWithWidth:outputPixelBufferWidth height:outputPixelBufferHeight];
        
        // setup resize params
        GLint location1 = glueGetUniformLocation(yuv2yuvProgram, "yPlane");
        GLint location2 = glueGetUniformLocation(yuv2yuvProgram, "uvPlane");
        GLint location3;
        glUseProgram(yuv2yuvProgram);
        glUniform1i(location1, 0);
        glUniform1i(location2, 1);
        
        // setup YUV params
        GLfloat resultYSize[] = { outputPixelBufferWidth - 1, outputPixelBufferHeight - 1, outputPixelBufferWidth, 0.0f };
        GLfloat resultYInvSize[] = { 1.f / resultYSize[0], 1.f / resultYSize[1], 1.f / resultYSize[2] };
        GLfloat resultUVSize[] = { outputPixelBufferWidth / 2 - 1, outputPixelBufferHeight / 2 - 1, outputPixelBufferWidth / 2, 0.0f };
        GLfloat resultUVInvSize[] = { 1.f / resultUVSize[0], 1.f / resultUVSize[1], 1.f / resultUVSize[2] };
        
        location1 = glueGetUniformLocation(yPlanarProgram, "resultSize");
        location2 = glueGetUniformLocation(yPlanarProgram, "resultInvSize");
        glUseProgram(yPlanarProgram);
        glUniform3fv(location1, 1, resultYSize);
        glUniform3fv(location2, 1, resultYInvSize);
        
        location1 = glueGetUniformLocation(uPlanarProgram, "resultSize");
        location2 = glueGetUniformLocation(uPlanarProgram, "resultInvSize");
        location3 = glueGetUniformLocation(uPlanarProgram, "planeSize");
        glUseProgram(uPlanarProgram);
        glUniform3fv(location1, 1, resultUVSize);
        glUniform3fv(location2, 1, resultUVInvSize);
        glUniform3fv(location3, 1, resultYSize);
        
        location1 = glueGetUniformLocation(vPlanarProgram, "resultSize");
        location2 = glueGetUniformLocation(vPlanarProgram, "resultInvSize");
        location3 = glueGetUniformLocation(vPlanarProgram, "planeSize");
        glUseProgram(vPlanarProgram);
        glUniform3fv(location1, 1, resultUVSize);
        glUniform3fv(location2, 1, resultUVInvSize);
        glUniform3fv(location3, 1, resultYSize);
        
        isFirstRenderCall = NO;
    }
    
    // Pass 1: resizing
    [offscreenFrameBuffer[1] beginRender];
    //glClear(GL_COLOR_BUFFER_BIT);
    
    // We also need to recalculate texture vertices in case the zoom level has changed
    [self generateTextureVertices:cropInputTextureVertices];
    
    // We should lock/unlock input pixel buffer to prevent strange artifacts 
    CVPixelBufferLockBaseAddress(inputPixelBuffer, 0);
    // Bind the input texture containing a new video frame, ensuring the texture vertices crop the input
    glActiveTexture(GL_TEXTURE0);
    inputTexture[0] = [self createTextureLinkedToBuffer:inputPixelBuffer withCache:inputTextureCache textureType:TT_LUMA];
    glActiveTexture(GL_TEXTURE1);
    inputTexture[1] = [self createTextureLinkedToBuffer:inputPixelBuffer withCache:inputTextureCache textureType:TT_CHROMA];//*/
    CVPixelBufferUnlockBaseAddress(inputPixelBuffer, 0);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, originCentredSquareVertices);
    glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, cropInputTextureVertices);
    
    // Render video frame offscreen to the FBO
    glUseProgram(yuv2yuvProgram);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    // Cleanup input texture
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, 0); // unbind
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, 0); // unbind
    //
    if(inputTexture[0]) CFRelease(inputTexture[0]), inputTexture[0] = NULL;
    if(inputTexture[1]) CFRelease(inputTexture[1]), inputTexture[1] = NULL;
    CVOpenGLESTextureCacheFlush(inputTextureCache, 0);//*/
    
    [offscreenFrameBuffer[1] endRender];
    
    // Pass 2: render YUV
    [offscreenFrameBuffer[0] beginRender];
    [offscreenFrameBuffer[1] bindTexture];
    //glClear(GL_COLOR_BUFFER_BIT);
    
    // render Y
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, yPlaneVertices);
    glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, yPlaneUVs);
    
    glUseProgram(yPlanarProgram);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    //render U
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, uPlaneVertices);
    glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, uvPlaneUVs);
    
    glUseProgram(uPlanarProgram);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    //render V
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, vPlaneVertices);
    glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, uvPlaneUVs);
    
    glUseProgram(vPlanarProgram);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindTexture(GL_TEXTURE_2D, 0); // unbind
    [offscreenFrameBuffer[0] endRender];//*/
    
    //glFlush();
    //glFinish();
    
    // Process using delegate
    //[NSThread detachNewThreadSelector:@selector(handleOutputFrame:) toTarget:self.outputDelegate withObject:(__bridge id)(outputPixelBuffer)];
    [self.outputDelegate handleOutputFrame:outputPixelBuffer];
    
    // Cleanup output texture (but do not release)
    CVOpenGLESTextureCacheFlush(outputTextureCache, 0);
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
    
    //  Create a new video output texture cache
    err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, (__bridge CVEAGLContext)((__bridge void *)(oglContext)), NULL, &outputTextureCache);
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
                                         textureType: (int)textureType
{
    size_t planeIndex = (textureType == TT_CHROMA) ? 1 : 0;
    GLint format = (textureType == TT_RGBA) ? GL_RGBA :
                        (textureType == TT_LUMA) ? GL_LUMINANCE : GL_LUMINANCE_ALPHA;
    unsigned int width = CVPixelBufferGetWidth(pixelBuffer) >> planeIndex;
    unsigned int height = CVPixelBufferGetHeight(pixelBuffer) >> planeIndex;
    CVOpenGLESTextureRef texture = NULL;
    CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, 
                                                                textureCache,
                                                                pixelBuffer,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                format,
                                                                width,
                                                                height,
                                                                format,
                                                                GL_UNSIGNED_BYTE,
                                                                planeIndex,
                                                                &texture);

    
    if (!texture || err) {
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);  
    }
    
    // Set texture parameters
	glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture));
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    return texture;
}

@end
