//
//  SLSOpenGLES20Renderer.m
//  Molecules
//
//  Created by Brad Larson on 4/12/2011.
//  Copyright 2011 Sunset Lake Software LLC. All rights reserved.
//

#import "SLSOpenGLES20Renderer.h"
#import "GLProgram.h"

#define AMBIENTOCCLUSIONTEXTUREWIDTH 1024

@implementation SLSOpenGLES20Renderer

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithContext:(EAGLContext *)newContext;
{
	if (![super initWithContext:newContext])
    {
		return nil;
    }

   //  0.312757, 0.248372, 0.916785
    // 0.0, -0.7071, 0.7071
    
    lightDirection[0] = 0.312757;
	lightDirection[1] = 0.248372;
	lightDirection[2] = 0.916785;

    [self initializeShaders];
    

    return self;
}

- (void)dealloc 
{    
    [self freeVertexBuffers];
    
	[super dealloc];
}

#pragma mark -
#pragma mark Model manipulation

- (void)rotateModelFromScreenDisplacementInX:(float)xRotation inY:(float)yRotation;
{
	// Perform incremental rotation based on current angles in X and Y	
	GLfloat totalRotation = sqrt(xRotation*xRotation + yRotation*yRotation);
	
	CATransform3D temporaryMatrix = CATransform3DRotate(currentCalculatedMatrix, totalRotation * M_PI / 180.0, 
														((-xRotation/totalRotation) * currentCalculatedMatrix.m12 + (-yRotation/totalRotation) * currentCalculatedMatrix.m11),
														((-xRotation/totalRotation) * currentCalculatedMatrix.m22 + (-yRotation/totalRotation) * currentCalculatedMatrix.m21),
														((-xRotation/totalRotation) * currentCalculatedMatrix.m32 + (-yRotation/totalRotation) * currentCalculatedMatrix.m31));
    
	if ((temporaryMatrix.m11 >= -100.0) && (temporaryMatrix.m11 <= 100.0))
    {
		currentCalculatedMatrix = temporaryMatrix;
    }    
}

- (void)translateModelByScreenDisplacementInX:(float)xTranslation inY:(float)yTranslation;
{
    /*
    // Translate the model by the accumulated amount
	float currentScaleFactor = sqrt(pow(currentCalculatedMatrix.m11, 2.0f) + pow(currentCalculatedMatrix.m12, 2.0f) + pow(currentCalculatedMatrix.m13, 2.0f));	
	
	xTranslation = xTranslation / (currentScaleFactor * currentScaleFactor);
	yTranslation = yTranslation / (currentScaleFactor * currentScaleFactor);
    
	// Use the (0,4,8) components to figure the eye's X axis in the model coordinate system, translate along that
	CATransform3D temporaryMatrix = CATransform3DTranslate(currentCalculatedMatrix, xTranslation * currentCalculatedMatrix.m11, xTranslation * currentCalculatedMatrix.m21, xTranslation * currentCalculatedMatrix.m31);
	// Use the (1,5,9) components to figure the eye's Y axis in the model coordinate system, translate along that
	temporaryMatrix = CATransform3DTranslate(temporaryMatrix, yTranslation * currentCalculatedMatrix.m12, yTranslation * currentCalculatedMatrix.m22, yTranslation * currentCalculatedMatrix.m32);	
	
	if ((temporaryMatrix.m11 >= -100.0) && (temporaryMatrix.m11 <= 100.0))
    {
		currentCalculatedMatrix = temporaryMatrix;
    }
     */
}

#pragma mark -
#pragma mark OpenGL drawing support

- (void)loadOrthoMatrix:(GLfloat *)matrix left:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top near:(GLfloat)near far:(GLfloat)far;
{
    GLfloat r_l = right - left;
    GLfloat t_b = top - bottom;
    GLfloat f_n = far - near;
    GLfloat tx = - (right + left) / (right - left);
    GLfloat ty = - (top + bottom) / (top - bottom);
    GLfloat tz = - (far + near) / (far - near);
    
    matrix[0] = 2.0f / r_l;
    matrix[1] = 0.0f;
    matrix[2] = 0.0f;
    matrix[3] = tx;
    
    matrix[4] = 0.0f;
    matrix[5] = 2.0f / t_b;
    matrix[6] = 0.0f;
    matrix[7] = ty;
    
    matrix[8] = 0.0f;
    matrix[9] = 0.0f;
    matrix[10] = 2.0f / f_n;
    matrix[11] = tz;
    
    matrix[12] = 0.0f;
    matrix[13] = 0.0f;
    matrix[14] = 0.0f;
    matrix[15] = 1.0f;
}

- (BOOL)createFramebuffersForLayer:(CAEAGLLayer *)glLayer;
{
    [EAGLContext setCurrentContext:context];

    // Need this to make the layer dimensions an even multiple of 32 for performance reasons
	// Also, the 4.2 Simulator will not display the 
	CGRect layerBounds = glLayer.bounds;
	CGFloat newWidth = (CGFloat)((int)layerBounds.size.width / 32) * 32.0f;
	CGFloat newHeight = (CGFloat)((int)layerBounds.size.height / 32) * 32.0f;
	glLayer.bounds = CGRectMake(layerBounds.origin.x, layerBounds.origin.y, newWidth, newHeight);

    glEnable(GL_TEXTURE_2D);

    [self createFramebuffer:&viewFramebuffer size:CGSizeZero renderBuffer:&viewRenderbuffer depthBuffer:&viewDepthBuffer texture:NULL layer:glLayer];    
//    [self createFramebuffer:&depthPassFramebuffer size:CGSizeMake(backingWidth, backingHeight) renderBuffer:&depthPassRenderbuffer depthBuffer:&depthPassDepthBuffer texture:&depthPassTexture layer:glLayer];
    [self createFramebuffer:&depthPassFramebuffer size:CGSizeMake(backingWidth, backingHeight) renderBuffer:&depthPassRenderbuffer depthBuffer:NULL texture:&depthPassTexture layer:glLayer];
    [self createFramebuffer:&ambientOcclusionFramebuffer size:CGSizeMake(AMBIENTOCCLUSIONTEXTUREWIDTH, AMBIENTOCCLUSIONTEXTUREWIDTH) renderBuffer:&ambientOcclusionRenderbuffer depthBuffer:NULL texture:&ambientOcclusionTexture layer:glLayer];
    
    [self switchToDisplayFramebuffer];
    glViewport(0, 0, backingWidth, backingHeight);

    [self loadOrthoMatrix:orthographicMatrix left:-1.0 right:1.0 bottom:(-1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) top:(1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) near:-4.0 far:4.0];
    
    return YES;
}

- (BOOL)createFramebuffer:(GLuint *)framebufferPointer size:(CGSize)bufferSize renderBuffer:(GLuint *)renderbufferPointer depthBuffer:(GLuint *)depthbufferPointer texture:(GLuint *)backingTexturePointer layer:(CAEAGLLayer *)layer;
{
    glGenFramebuffers(1, framebufferPointer);
    glBindFramebuffer(GL_FRAMEBUFFER, *framebufferPointer);
	
    if (renderbufferPointer != NULL)
    {
        glGenRenderbuffers(1, renderbufferPointer);
        glBindRenderbuffer(GL_RENDERBUFFER, *renderbufferPointer);
        
        if (backingTexturePointer == NULL)
        {
            [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
            glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
            glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
            bufferSize = CGSizeMake(backingWidth, backingHeight);
        }
        else
        {
            glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, bufferSize.width, bufferSize.height);
        }
        
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, *renderbufferPointer);	
    }
    
    if (depthbufferPointer != NULL)
    {
        glGenRenderbuffers(1, depthbufferPointer);
        glBindRenderbuffer(GL_RENDERBUFFER, *depthbufferPointer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, bufferSize.width, bufferSize.height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, *depthbufferPointer);
    }
	
    if (backingTexturePointer != NULL)
    {
        glGenTextures(1, backingTexturePointer);
        
        glBindTexture(GL_TEXTURE_2D, *backingTexturePointer);
        //        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        //        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER, GL_NEAREST );
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER, GL_NEAREST );
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferSize.width, bufferSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, *backingTexturePointer, 0);
        glBindTexture(GL_TEXTURE_2D, 0);
    }	
	
	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) 
	{
		NSLog(@"Incomplete FBO: %d", status);
        assert(false);
    }
    
    return YES;
}

- (void)initializeShaders;
{
    [EAGLContext setCurrentContext:context];

    sphereRaytracingProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"SphereRaytracing" fragmentShaderFilename:@"SphereRaytracing"];
	[sphereRaytracingProgram addAttribute:@"position"];
	[sphereRaytracingProgram addAttribute:@"inputImpostorSpaceCoordinate"];
	if (![sphereRaytracingProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [sphereRaytracingProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [sphereRaytracingProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [sphereRaytracingProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		[sphereRaytracingProgram release];
		sphereRaytracingProgram = nil;
	}
    
    sphereRaytracingPositionAttribute = [sphereRaytracingProgram attributeIndex:@"position"];
    sphereRaytracingImpostorSpaceAttribute = [sphereRaytracingProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
	sphereRaytracingModelViewMatrix = [sphereRaytracingProgram uniformIndex:@"modelViewProjMatrix"];
    sphereRaytracingLightPosition = [sphereRaytracingProgram uniformIndex:@"lightPosition"];
    sphereRaytracingRadius = [sphereRaytracingProgram uniformIndex:@"sphereRadius"];
    sphereRaytracingColor = [sphereRaytracingProgram uniformIndex:@"sphereColor"];
    sphereRaytracingDepthTexture = [sphereRaytracingProgram uniformIndex:@"depthTexture"];
    sphereRaytracingOrthographicMatrix = [sphereRaytracingProgram uniformIndex:@"orthographicMatrix"];
    sphereRaytracingPrecalculatedDepthTexture = [sphereRaytracingProgram uniformIndex:@"precalculatedSphereDepthTexture"];
    sphereRaytracingInverseModelViewMatrix = [sphereRaytracingProgram uniformIndex:@"inverseModelViewProjMatrix"];

    cylinderRaytracingProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"CylinderRaytracing" fragmentShaderFilename:@"CylinderRaytracing"];
	[cylinderRaytracingProgram addAttribute:@"position"];
	[cylinderRaytracingProgram addAttribute:@"direction"];
	[cylinderRaytracingProgram addAttribute:@"inputImpostorSpaceCoordinate"];
    
	if (![cylinderRaytracingProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [cylinderRaytracingProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [cylinderRaytracingProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [cylinderRaytracingProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		[cylinderRaytracingProgram release];
		cylinderRaytracingProgram = nil;
	}
    
    cylinderRaytracingPositionAttribute = [cylinderRaytracingProgram attributeIndex:@"position"];
    cylinderRaytracingDirectionAttribute = [cylinderRaytracingProgram attributeIndex:@"direction"];
    cylinderRaytracingImpostorSpaceAttribute = [cylinderRaytracingProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
	cylinderRaytracingModelViewMatrix = [cylinderRaytracingProgram uniformIndex:@"modelViewProjMatrix"];
    cylinderRaytracingLightPosition = [cylinderRaytracingProgram uniformIndex:@"lightPosition"];
    cylinderRaytracingRadius = [cylinderRaytracingProgram uniformIndex:@"cylinderRadius"];
    cylinderRaytracingColor = [cylinderRaytracingProgram uniformIndex:@"cylinderColor"];
    cylinderRaytracingDepthTexture = [cylinderRaytracingProgram uniformIndex:@"depthTexture"];
    cylinderRaytracingOrthographicMatrix = [cylinderRaytracingProgram uniformIndex:@"orthographicMatrix"];
    cylinderRaytracingInverseModelViewMatrix = [cylinderRaytracingProgram uniformIndex:@"inverseModelViewProjMatrix"];
    
    sphereDepthProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"SphereDepth" fragmentShaderFilename:@"SphereDepth"];
	[sphereDepthProgram addAttribute:@"position"];
	[sphereDepthProgram addAttribute:@"inputImpostorSpaceCoordinate"];
	if (![sphereDepthProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [sphereDepthProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [sphereDepthProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [sphereDepthProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		[sphereDepthProgram release];
		sphereDepthProgram = nil;
	}
    
    sphereDepthPositionAttribute = [sphereDepthProgram attributeIndex:@"position"];
    sphereDepthImpostorSpaceAttribute = [sphereDepthProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
	sphereDepthModelViewMatrix = [sphereDepthProgram uniformIndex:@"modelViewProjMatrix"];
    sphereDepthRadius = [sphereDepthProgram uniformIndex:@"sphereRadius"];
    sphereDepthOrthographicMatrix = [sphereDepthProgram uniformIndex:@"orthographicMatrix"];
    sphereDepthPrecalculatedDepthTexture = [sphereDepthProgram uniformIndex:@"precalculatedSphereDepthTexture"];

    
    cylinderDepthProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"CylinderDepth" fragmentShaderFilename:@"CylinderDepth"];
	[cylinderDepthProgram addAttribute:@"position"];
	[cylinderDepthProgram addAttribute:@"direction"];
	[cylinderDepthProgram addAttribute:@"inputImpostorSpaceCoordinate"];
    
	if (![cylinderDepthProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [cylinderDepthProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [cylinderDepthProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [cylinderDepthProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		[cylinderDepthProgram release];
		cylinderDepthProgram = nil;
	}
    
    cylinderDepthPositionAttribute = [cylinderDepthProgram attributeIndex:@"position"];
    cylinderDepthDirectionAttribute = [cylinderDepthProgram attributeIndex:@"direction"];
    cylinderDepthImpostorSpaceAttribute = [cylinderDepthProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
	cylinderDepthModelViewMatrix = [cylinderDepthProgram uniformIndex:@"modelViewProjMatrix"];
    cylinderDepthRadius = [cylinderDepthProgram uniformIndex:@"cylinderRadius"];
    cylinderDepthOrthographicMatrix = [cylinderDepthProgram uniformIndex:@"orthographicMatrix"];

    sphereAmbientOcclusionProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"SphereAmbientOcclusion" fragmentShaderFilename:@"SphereAmbientOcclusion"];
	[sphereAmbientOcclusionProgram addAttribute:@"position"];
	[sphereAmbientOcclusionProgram addAttribute:@"inputImpostorSpaceCoordinate"];
	if (![sphereAmbientOcclusionProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [sphereAmbientOcclusionProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [sphereAmbientOcclusionProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [sphereAmbientOcclusionProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		[sphereAmbientOcclusionProgram release];
		sphereAmbientOcclusionProgram = nil;
	}
    
    sphereAmbientOcclusionPositionAttribute = [sphereRaytracingProgram attributeIndex:@"position"];
    sphereAmbientOcclusionImpostorSpaceAttribute = [sphereRaytracingProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
	sphereAmbientOcclusionModelViewMatrix = [sphereRaytracingProgram uniformIndex:@"modelViewProjMatrix"];
    sphereAmbientOcclusionRadius = [sphereRaytracingProgram uniformIndex:@"sphereRadius"];
    sphereAmbientOcclusionDepthTexture = [sphereRaytracingProgram uniformIndex:@"depthTexture"];
    sphereAmbientOcclusionOrthographicMatrix = [sphereRaytracingProgram uniformIndex:@"orthographicMatrix"];
    sphereAmbientOcclusionPrecalculatedDepthTexture = [sphereRaytracingProgram uniformIndex:@"precalculatedSphereDepthTexture"];
    sphereAmbientOcclusionInverseModelViewMatrix = [sphereRaytracingProgram uniformIndex:@"inverseModelViewProjMatrix"];

    [self generateSphereDepthMapTexture];
}

- (void)switchToDisplayFramebuffer;
{
	glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    
    glViewport(0, 0, backingWidth, backingHeight);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, 0);
}

- (void)switchToDepthPassFramebuffer;
{
	glBindFramebuffer(GL_FRAMEBUFFER, depthPassFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, depthPassRenderbuffer);
    
    glViewport(0, 0, backingWidth, backingHeight);
    
    //    glActiveTexture(GL_TEXTURE1);
    //    glBindTexture(GL_TEXTURE_2D, depthPassTexture);
}

- (void)switchToAmbientOcclusionFramebuffer;
{
	glBindFramebuffer(GL_FRAMEBUFFER, ambientOcclusionFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, ambientOcclusionRenderbuffer);
    
    glViewport(0, 0, AMBIENTOCCLUSIONTEXTUREWIDTH, AMBIENTOCCLUSIONTEXTUREWIDTH);
}

#define SPHEREDEPTHTEXTUREWIDTH 256

- (void)generateSphereDepthMapTexture;
{
    // This takes only 95 ms on an iPad 1, so it's worth it for the 8% - 18% per-frame speedup 
    
    unsigned char *sphereDepthTextureData = (unsigned char *)malloc(SPHEREDEPTHTEXTUREWIDTH * SPHEREDEPTHTEXTUREWIDTH);

    glGenTextures(1, &sphereDepthMappingTexture);

    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, sphereDepthMappingTexture);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_NEAREST);
//	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    for (unsigned int currentColumnInTexture = 0; currentColumnInTexture < SPHEREDEPTHTEXTUREWIDTH; currentColumnInTexture++)
    {
        float normalizedYLocation = -1.0 + 2.0 * (float)currentColumnInTexture / (float)SPHEREDEPTHTEXTUREWIDTH;
        for (unsigned int currentRowInTexture = 0; currentRowInTexture < SPHEREDEPTHTEXTUREWIDTH; currentRowInTexture++)
        {
            float normalizedXLocation = -1.0 + 2.0 * (float)currentRowInTexture / (float)SPHEREDEPTHTEXTUREWIDTH;
            unsigned char currentDepthByte = 0;
            
            float distanceFromCenter = sqrt(normalizedXLocation * normalizedXLocation + normalizedYLocation * normalizedYLocation);
            if (distanceFromCenter <= 1.0)
            {
                currentDepthByte = round(255.0 * sqrt(1.0 - distanceFromCenter * distanceFromCenter));
            }

            sphereDepthTextureData[currentColumnInTexture * SPHEREDEPTHTEXTUREWIDTH + currentRowInTexture] = currentDepthByte;
        }
    }
    
	glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, SPHEREDEPTHTEXTUREWIDTH, SPHEREDEPTHTEXTUREWIDTH, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, sphereDepthTextureData);
//    glGenerateMipmap(GL_TEXTURE_2D);

    free(sphereDepthTextureData);
}

- (void)destroyFramebuffers;
{
	if (viewFramebuffer)
	{
		glDeleteFramebuffers(1, &viewFramebuffer);
		viewFramebuffer = 0;
	}
	
	if (viewRenderbuffer)
	{
		glDeleteRenderbuffers(1, &viewRenderbuffer);
		viewRenderbuffer = 0;
	}
    
	if (viewDepthBuffer)
	{
		glDeleteRenderbuffers(1, &viewDepthBuffer);
		viewDepthBuffer = 0;
	}
}

- (void)configureProjection;
{
    [self loadOrthoMatrix:orthographicMatrix left:-1.0 right:1.0 bottom:(-1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) top:(1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) near:-1.0 far:4.0];
}

- (void)presentRenderBuffer;
{
   [context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)clearScreen;
{
	[EAGLContext setCurrentContext:context];
    
    [self switchToDisplayFramebuffer];
	
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [self presentRenderBuffer];
}

#pragma mark -
#pragma mark Actual OpenGL rendering

- (void)renderFrameForMolecule:(SLSMolecule *)molecule;
{
    CFTimeInterval previousTimestamp = CFAbsoluteTimeGetCurrent();

    GLfloat currentModelViewMatrix[16];
    [self convert3DTransform:&currentCalculatedMatrix toMatrix:currentModelViewMatrix];

    [self renderDepthTextureForModelViewMatrix:currentModelViewMatrix];
    [self renderRaytracedSceneForModelViewMatrix:currentModelViewMatrix];
    
    // Discarding is only supported starting with 4.0, so I need to do a check here for 3.2 devices
//    const GLenum discards[]  = {GL_DEPTH_ATTACHMENT};
//    glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, discards);
    
    [self presentRenderBuffer];
    
    CFTimeInterval frameDuration = CFAbsoluteTimeGetCurrent() - previousTimestamp;
    
    NSLog(@"Frame duration: %f ms", frameDuration * 1000.0);
}

#pragma mark -
#pragma mark Molecule 3-D geometry generation

- (void)configureBasedOnNumberOfAtoms:(unsigned int)numberOfAtoms numberOfBonds:(unsigned int)numberOfBonds;
{
    widthOfAtomAOTexturePatch = AMBIENTOCCLUSIONTEXTUREWIDTH / sqrt(numberOfAtoms + numberOfAtoms);
    normalizedAOTexturePatchWidth = (GLfloat)widthOfAtomAOTexturePatch / (GLfloat)AMBIENTOCCLUSIONTEXTUREWIDTH;
    
    previousAmbientOcclusionOffset[0] = 0.0;
    previousAmbientOcclusionOffset[1] = 0.0;
}

- (void)addAtomToVertexBuffers:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint;
{
    GLushort baseToAddToIndices = numberOfAtomVertices[atomType];

    GLfloat newVertex[3];
    newVertex[0] = newPoint.x;
    newVertex[1] = newPoint.y;
    newVertex[2] = newPoint.z;

    GLfloat lowerLeftTexture[2] = {-1.0, -1.0};
    GLfloat lowerRightTexture[2] = {1.0, -1.0};
    GLfloat upperLeftTexture[2] = {-1.0, 1.0};
    GLfloat upperRightTexture[2] = {1.0, 1.0};

    // Add four copies of this vertex, that will be translated in the vertex shader into the billboard
    // Interleave texture coordinates in VBO
    [self addVertex:newVertex forAtomType:atomType];
    [self addTextureCoordinate:lowerLeftTexture forAtomType:atomType];
    [self addVertex:newVertex forAtomType:atomType];
    [self addTextureCoordinate:lowerRightTexture forAtomType:atomType];
    [self addVertex:newVertex forAtomType:atomType];
    [self addTextureCoordinate:upperLeftTexture forAtomType:atomType];
    [self addVertex:newVertex forAtomType:atomType];
    [self addTextureCoordinate:upperRightTexture forAtomType:atomType];

    //    123243
    GLushort newIndices[6];
    newIndices[0] = baseToAddToIndices;
    newIndices[1] = baseToAddToIndices + 1;
    newIndices[2] = baseToAddToIndices + 2;
    newIndices[3] = baseToAddToIndices + 1;
    newIndices[4] = baseToAddToIndices + 3;
    newIndices[5] = baseToAddToIndices + 2;

    [self addIndices:newIndices size:6 forAtomType:atomType];
}

- (void)addBondToVertexBuffersWithStartPoint:(SLS3DPoint)startPoint endPoint:(SLS3DPoint)endPoint bondColor:(GLubyte *)bondColor bondType:(SLSBondType)bondType;
{
    if (currentBondVBO >= MAX_BOND_VBOS)
    {
        return;
    }

    GLushort baseToAddToIndices = numberOfBondVertices[currentBondVBO];

    // Vertex positions, duplicated for later displacement at each end
    // Interleave the directions and texture coordinates for the VBO
    GLfloat newVertex[3], cylinderDirection[3];
    
    cylinderDirection[0] = endPoint.x - startPoint.x;
    cylinderDirection[1] = endPoint.y - startPoint.y;
    cylinderDirection[2] = endPoint.z - startPoint.z;

    // Impostor space coordinates
    GLfloat lowerLeftTexture[2] = {-1.0, -1.0};
    GLfloat lowerRightTexture[2] = {1.0, -1.0};
    GLfloat upperLeftTexture[2] = {-1.0, 1.0};
    GLfloat upperRightTexture[2] = {1.0, 1.0};

    newVertex[0] = startPoint.x;
    newVertex[1] = startPoint.y;
    newVertex[2] = startPoint.z;

    [self addBondVertex:newVertex];
    [self addBondDirection:cylinderDirection];
    [self addBondTextureCoordinate:lowerLeftTexture];
    [self addBondVertex:newVertex];
    [self addBondDirection:cylinderDirection];
    [self addBondTextureCoordinate:lowerRightTexture];
    
    newVertex[0] = endPoint.x;
    newVertex[1] = endPoint.y;
    newVertex[2] = endPoint.z;
    
    [self addBondVertex:newVertex];
    [self addBondDirection:cylinderDirection];
    [self addBondTextureCoordinate:upperLeftTexture];
    [self addBondVertex:newVertex];
    [self addBondDirection:cylinderDirection];
    [self addBondTextureCoordinate:upperRightTexture];
    
    // Vertex indices
    //    123243
    GLushort newIndices[6];
    newIndices[0] = baseToAddToIndices;
    newIndices[1] = baseToAddToIndices + 1;
    newIndices[2] = baseToAddToIndices + 2;
    newIndices[3] = baseToAddToIndices + 1;
    newIndices[4] = baseToAddToIndices + 3;
    newIndices[5] = baseToAddToIndices + 2;
    
    [self addBondIndices:newIndices size:6];
}

- (void)addVertex:(GLfloat *)newVertex forAtomType:(SLSAtomType)atomType;
{
    if (atomVBOs[atomType] == nil)
    {
        atomVBOs[atomType] = [[NSMutableData alloc] init];
    }
    
	[atomVBOs[atomType] appendBytes:newVertex length:(sizeof(GLfloat) * 3)];	
    
	numberOfAtomVertices[atomType]++;
	totalNumberOfVertices++;
}

- (void)addBondVertex:(GLfloat *)newVertex;
{
    if (bondVBOs[currentBondVBO] == nil)
    {
        bondVBOs[currentBondVBO] = [[NSMutableData alloc] init];
    }
    	
	[bondVBOs[currentBondVBO] appendBytes:newVertex length:(sizeof(GLfloat) * 3)];	
    
	numberOfBondVertices[currentBondVBO]++;
	totalNumberOfVertices++;
}

- (void)addTextureCoordinate:(GLfloat *)newTextureCoordinate forAtomType:(SLSAtomType)atomType;
{
    if (atomVBOs[atomType] == nil)
    {
        atomVBOs[atomType] = [[NSMutableData alloc] init];
    }
    
	[atomVBOs[atomType] appendBytes:newTextureCoordinate length:(sizeof(GLfloat) * 2)];	
}

- (void)addAmbientOcclusionTextureOffset:(GLfloat *)ambientOcclusionOffset forAtomType:(SLSAtomType)atomType;
{
    
}

- (void)addBondDirection:(GLfloat *)newDirection;
{
    if (bondVBOs[currentBondVBO] == nil)
    {
        bondVBOs[currentBondVBO] = [[NSMutableData alloc] init];
    }
    
	[bondVBOs[currentBondVBO] appendBytes:newDirection length:(sizeof(GLfloat) * 3)];	
}

- (void)addBondTextureCoordinate:(GLfloat *)newTextureCoordinate;
{
    if (bondVBOs[currentBondVBO] == nil)
    {
        bondVBOs[currentBondVBO] = [[NSMutableData alloc] init];
    }
    
	[bondVBOs[currentBondVBO] appendBytes:newTextureCoordinate length:(sizeof(GLfloat) * 2)];	
}

#pragma mark -
#pragma mark OpenGL drawing routines

- (void)renderDepthTextureForModelViewMatrix:(GLfloat *)depthModelViewMatrix;
{
    [self switchToDepthPassFramebuffer];
    
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
    glDisable(GL_DEPTH_TEST); 
    glEnable(GL_BLEND);
    glBlendEquation(GL_MIN_EXT);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glClear(GL_COLOR_BUFFER_BIT);
//    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Draw the spheres
    [sphereDepthProgram use];
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, sphereDepthMappingTexture);
    glUniform1i(sphereDepthPrecalculatedDepthTexture, 2);

    glUniformMatrix4fv(sphereDepthModelViewMatrix, 1, 0, depthModelViewMatrix);
    glUniformMatrix4fv(sphereDepthOrthographicMatrix, 1, 0, orthographicMatrix);

    float sphereScaleFactor = overallMoleculeScaleFactor * currentModelScaleFactor * atomRadiusScaleFactor;
    GLsizei atomVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2;
    
    for (unsigned int currentAtomType = 0; currentAtomType < NUM_ATOMTYPES; currentAtomType++)
    {
        if (atomIndexBufferHandle[currentAtomType] != 0)
        {
            glUniform1f(sphereDepthRadius, atomProperties[currentAtomType].atomRadius * sphereScaleFactor);

            // Bind the VBO and attach it to the program
            glBindBuffer(GL_ARRAY_BUFFER, atomVertexBufferHandles[currentAtomType]); 
            glVertexAttribPointer(sphereDepthPositionAttribute, 3, GL_FLOAT, 0, atomVBOStride, (char *)NULL + 0);
            glEnableVertexAttribArray(sphereDepthPositionAttribute);
            glVertexAttribPointer(sphereDepthImpostorSpaceAttribute, 2, GL_FLOAT, 0, atomVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
            glEnableVertexAttribArray(sphereDepthImpostorSpaceAttribute);
            
            // Bind the index buffer and draw to the screen
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, atomIndexBufferHandle[currentAtomType]);    
            glDrawElements(GL_TRIANGLES, numberOfIndicesInBuffer[currentAtomType], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }
    }
    
    // Draw the cylinders    
    [cylinderDepthProgram use];

    float cylinderScaleFactor = overallMoleculeScaleFactor * currentModelScaleFactor * bondRadiusScaleFactor;
    GLsizei bondVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2;
	GLfloat bondRadius = 1.0;

    glUniform1f(cylinderDepthRadius, bondRadius * cylinderScaleFactor);
    glUniformMatrix4fv(cylinderDepthModelViewMatrix, 1, 0, depthModelViewMatrix);
    glUniformMatrix4fv(cylinderDepthOrthographicMatrix, 1, 0, orthographicMatrix);

    for (unsigned int currentBondVBOIndex = 0; currentBondVBOIndex < MAX_BOND_VBOS; currentBondVBOIndex++)
    {
        // Draw bonds next
        if (bondVertexBufferHandle[currentBondVBOIndex] != 0)
        {
            // Bind the VBO and attach it to the program
            glBindBuffer(GL_ARRAY_BUFFER, bondVertexBufferHandle[currentBondVBOIndex]); 
            glVertexAttribPointer(cylinderDepthPositionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + 0);
            glEnableVertexAttribArray(cylinderDepthPositionAttribute);
            glVertexAttribPointer(cylinderDepthDirectionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
            glEnableVertexAttribArray(cylinderDepthDirectionAttribute);
            glVertexAttribPointer(cylinderDepthImpostorSpaceAttribute, 2, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 3));
            glEnableVertexAttribArray(cylinderDepthImpostorSpaceAttribute);
            
            // Bind the index buffer and draw to the screen
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bondIndexBufferHandle[currentBondVBOIndex]);    
            glDrawElements(GL_TRIANGLES, numberOfBondIndicesInBuffer[currentBondVBOIndex], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }
    }
}

- (void)renderRaytracedSceneForModelViewMatrix:(GLfloat *)raytracingModelViewMatrix;
{
    [self switchToDisplayFramebuffer];

    CATransform3D inverseMatrix = CATransform3DInvert(currentCalculatedMatrix);
    GLfloat inverseModelViewMatrix[16];
    [self convert3DTransform:&inverseMatrix toMatrix:inverseModelViewMatrix];
    
    glDisable(GL_BLEND);
    //    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    //    glBlendEquation(GL_FUNC_ADD);
    
    glEnable(GL_DEPTH_TEST);
    
    //    glDepthMask(GL_FALSE);
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // Draw the spheres
    [sphereRaytracingProgram use];
        
    glUniform3fv(sphereRaytracingLightPosition, 1, lightDirection);
    
    // Load in the depth texture from the previous pass
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, depthPassTexture);
    glUniform1i(sphereRaytracingDepthTexture, 0);

    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, sphereDepthMappingTexture);
    glUniform1i(sphereRaytracingPrecalculatedDepthTexture, 2);

    glUniformMatrix4fv(sphereRaytracingModelViewMatrix, 1, 0, raytracingModelViewMatrix);
    glUniformMatrix4fv(sphereRaytracingInverseModelViewMatrix, 1, 0, inverseModelViewMatrix);
    glUniformMatrix4fv(sphereRaytracingOrthographicMatrix, 1, 0, orthographicMatrix);

    float sphereScaleFactor = overallMoleculeScaleFactor * currentModelScaleFactor * atomRadiusScaleFactor;
    GLsizei atomVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2;
    
    for (unsigned int currentAtomType = 0; currentAtomType < NUM_ATOMTYPES; currentAtomType++)
    {
        if (atomIndexBufferHandle[currentAtomType] != 0)
        {
            glUniform1f(sphereRaytracingRadius, atomProperties[currentAtomType].atomRadius * sphereScaleFactor);
            glUniform3f(sphereRaytracingColor, (GLfloat)atomProperties[currentAtomType].redComponent / 255.0f , (GLfloat)atomProperties[currentAtomType].greenComponent / 255.0f, (GLfloat)atomProperties[currentAtomType].blueComponent / 255.0f);

            // Bind the VBO and attach it to the program
            glBindBuffer(GL_ARRAY_BUFFER, atomVertexBufferHandles[currentAtomType]); 
            glVertexAttribPointer(sphereRaytracingPositionAttribute, 3, GL_FLOAT, 0, atomVBOStride, (char *)NULL + 0);
            glEnableVertexAttribArray(sphereRaytracingPositionAttribute);
            glVertexAttribPointer(sphereRaytracingImpostorSpaceAttribute, 2, GL_FLOAT, 0, atomVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
            glEnableVertexAttribArray(sphereRaytracingImpostorSpaceAttribute);
            
            // Bind the index buffer and draw to the screen
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, atomIndexBufferHandle[currentAtomType]);    
            glDrawElements(GL_TRIANGLES, numberOfIndicesInBuffer[currentAtomType], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }
    }
        
    // Draw the cylinders
    [cylinderRaytracingProgram use];

    glUniform3fv(cylinderRaytracingLightPosition, 1, lightDirection);
    glUniform1i(cylinderRaytracingDepthTexture, 0);	

    float cylinderScaleFactor = overallMoleculeScaleFactor * currentModelScaleFactor * bondRadiusScaleFactor;
    GLsizei bondVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2;
	GLfloat bondRadius = 1.0;

    glUniform1f(cylinderRaytracingRadius, bondRadius * cylinderScaleFactor);
    glUniform3f(cylinderRaytracingColor, 0.75, 0.75, 0.75);
    glUniformMatrix4fv(cylinderRaytracingModelViewMatrix, 1, 0, raytracingModelViewMatrix);
    glUniformMatrix4fv(cylinderRaytracingOrthographicMatrix, 1, 0, orthographicMatrix);
    glUniformMatrix4fv(cylinderRaytracingInverseModelViewMatrix, 1, 0, inverseModelViewMatrix);

    for (unsigned int currentBondVBOIndex = 0; currentBondVBOIndex < MAX_BOND_VBOS; currentBondVBOIndex++)
    {
        // Draw bonds next
        if (bondVertexBufferHandle[currentBondVBOIndex] != 0)
        {

            // Bind the VBO and attach it to the program
            glBindBuffer(GL_ARRAY_BUFFER, bondVertexBufferHandle[currentBondVBOIndex]); 
            glVertexAttribPointer(cylinderRaytracingPositionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + 0);
            glEnableVertexAttribArray(cylinderRaytracingPositionAttribute);
            glVertexAttribPointer(cylinderRaytracingDirectionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
            glEnableVertexAttribArray(cylinderRaytracingDirectionAttribute);
            glVertexAttribPointer(cylinderRaytracingImpostorSpaceAttribute, 2, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 3));
            glEnableVertexAttribArray(cylinderRaytracingImpostorSpaceAttribute);
            
            // Bind the index buffer and draw to the screen
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bondIndexBufferHandle[currentBondVBOIndex]);
            glDrawElements(GL_TRIANGLES, numberOfBondIndicesInBuffer[currentBondVBOIndex], GL_UNSIGNED_SHORT, NULL);
        }
    }
        
    glBindTexture(GL_TEXTURE_2D, 0);
	glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

- (void)renderAmbientOcclusionTextureForModelViewMatrix:(GLfloat *)ambientOcclusionModelViewMatrix;
{
    [self switchToAmbientOcclusionFramebuffer];
    
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
    glDisable(GL_DEPTH_TEST); 
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Draw the spheres
    [sphereAmbientOcclusionProgram use];
    
    CATransform3D inverseMatrix = CATransform3DInvert(currentCalculatedMatrix);
    GLfloat inverseModelViewMatrix[16];
    [self convert3DTransform:&inverseMatrix toMatrix:inverseModelViewMatrix];
    glUniformMatrix4fv(sphereAmbientOcclusionInverseModelViewMatrix, 1, 0, inverseModelViewMatrix);

    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, sphereDepthMappingTexture);
    glUniform1i(sphereAmbientOcclusionPrecalculatedDepthTexture, 2);
    
    glUniformMatrix4fv(sphereAmbientOcclusionModelViewMatrix, 1, 0, ambientOcclusionModelViewMatrix);
    glUniformMatrix4fv(sphereAmbientOcclusionOrthographicMatrix, 1, 0, orthographicMatrix);
    
    float sphereScaleFactor = overallMoleculeScaleFactor * currentModelScaleFactor * atomRadiusScaleFactor;
    GLsizei atomVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2;
    
    for (unsigned int currentAtomType = 0; currentAtomType < NUM_ATOMTYPES; currentAtomType++)
    {
        if (atomIndexBufferHandle[currentAtomType] != 0)
        {
            glUniform1f(sphereAmbientOcclusionRadius, atomProperties[currentAtomType].atomRadius * sphereScaleFactor);
            
            // Bind the VBO and attach it to the program
            glBindBuffer(GL_ARRAY_BUFFER, atomVertexBufferHandles[currentAtomType]); 
            glVertexAttribPointer(sphereAmbientOcclusionPositionAttribute, 3, GL_FLOAT, 0, atomVBOStride, (char *)NULL + 0);
            glEnableVertexAttribArray(sphereAmbientOcclusionPositionAttribute);
            glVertexAttribPointer(sphereAmbientOcclusionImpostorSpaceAttribute, 2, GL_FLOAT, 0, atomVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
            glEnableVertexAttribArray(sphereAmbientOcclusionImpostorSpaceAttribute);
            
            // Bind the index buffer and draw to the screen
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, atomIndexBufferHandle[currentAtomType]);    
            glDrawElements(GL_TRIANGLES, numberOfIndicesInBuffer[currentAtomType], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }
    }
    
    /*
    // Draw the cylinders    
    [cylinderAmbientOcclusionProgram use];
    
    float cylinderScaleFactor = overallMoleculeScaleFactor * currentModelScaleFactor * bondRadiusScaleFactor;
    GLsizei bondVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2;
	GLfloat bondRadius = 1.0;
    
    glUniform1f(cylinderAmbientOcclusionRadius, bondRadius * cylinderScaleFactor);
    glUniformMatrix4fv(cylinderAmbientOcclusionModelViewMatrix, 1, 0, depthModelViewMatrix);
    glUniformMatrix4fv(cylinderAmbientOcclusionOrthographicMatrix, 1, 0, orthographicMatrix);
    
    for (unsigned int currentBondVBOIndex = 0; currentBondVBOIndex < MAX_BOND_VBOS; currentBondVBOIndex++)
    {
        // Draw bonds next
        if (bondVertexBufferHandle[currentBondVBOIndex] != 0)
        {
            // Bind the VBO and attach it to the program
            glBindBuffer(GL_ARRAY_BUFFER, bondVertexBufferHandle[currentBondVBOIndex]); 
            glVertexAttribPointer(cylinderAmbientOcclusionPositionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + 0);
            glEnableVertexAttribArray(cylinderAmbientOcclusionPositionAttribute);
            glVertexAttribPointer(cylinderAmbientOcclusionDirectionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
            glEnableVertexAttribArray(cylinderAmbientOcclusionDirectionAttribute);
            glVertexAttribPointer(cylinderAmbientOcclusionImpostorSpaceAttribute, 2, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 3));
            glEnableVertexAttribArray(cylinderAmbientOcclusionImpostorSpaceAttribute);
            
            // Bind the index buffer and draw to the screen
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bondIndexBufferHandle[currentBondVBOIndex]);    
            glDrawElements(GL_TRIANGLES, numberOfBondIndicesInBuffer[currentBondVBOIndex], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }
    }
*/
}

- (void)prepareAmbientOcclusionMap;
{
    GLfloat currentModelViewMatrix[16];
    CATransform3D currentDepthRotationMatrix = CATransform3DIdentity;
    
    [self convert3DTransform:&currentDepthRotationMatrix toMatrix:currentModelViewMatrix];
    
    [self renderDepthTextureForModelViewMatrix:currentModelViewMatrix];
    [self renderAmbientOcclusionTextureForModelViewMatrix:currentModelViewMatrix];
}

@end
