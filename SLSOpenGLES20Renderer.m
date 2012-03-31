//
//  SLSOpenGLES20Renderer.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 4/12/2011.
//

//#define USEWHITEBACKGROUND

#import "SLSOpenGLES20Renderer.h"
#import "GLProgram.h"

@implementation SLSOpenGLES20Renderer

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithContext:(EAGLContext *)newContext;
{
	if (!(self = [super initWithContext:newContext]))
    {
		return nil;
    }

   //  0.312757, 0.248372, 0.916785
    // 0.0, -0.7071, 0.7071
    
    [EAGLContext setCurrentContext:context];
    GLint maxTextureSize; 
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    
    // Use higher-resolution textures on the A5 and higher GPUs, because they can support it
    if (maxTextureSize > 2048)
    {
//        ambientOcclusionTextureWidth = 2048;
//        ambientOcclusionLookupTextureWidth = 512;
//        sphereDepthTextureWidth = 512;
        ambientOcclusionTextureWidth = 1024;
        ambientOcclusionLookupTextureWidth = 128;
        sphereDepthTextureWidth = 1024;
    }
    else
    {
        ambientOcclusionTextureWidth = 512;
        ambientOcclusionLookupTextureWidth = 128;
        sphereDepthTextureWidth = 256;
    }
    
    currentViewportSize = CGSizeZero;
    
    lightDirection[0] = 0.312757;
	lightDirection[1] = 0.248372;
	lightDirection[2] = 0.916785;

    [self initializeDepthShaders];
    [self initializeAmbientOcclusionShaders];
    [self initializeRaytracingShaders];

    return self;
}

- (void)dealloc 
{    
    [self freeVertexBuffers];
    
    if (ambientOcclusionFramebuffer)
    {
        glDeleteFramebuffers(1, &ambientOcclusionFramebuffer);
        ambientOcclusionFramebuffer = 0;
    }
    
    if (ambientOcclusionTexture)
    {
        glDeleteTextures(1, &ambientOcclusionTexture);
        ambientOcclusionTexture = 0;
    }

    if (sphereAOLookupFramebuffer)
    {
        glDeleteFramebuffers(1, &sphereAOLookupFramebuffer);
        sphereAOLookupFramebuffer = 0;
    }
    
    if (sphereAOLookupTexture)
    {
        glDeleteTextures(1, &sphereAOLookupTexture);
        sphereAOLookupTexture = 0;
    }

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
//        currentCalculatedMatrix = CATransform3DMakeRotation(M_PI, 0.0, 0.0, 1.0);

		currentCalculatedMatrix = temporaryMatrix;
    }    
}

- (void)translateModelByScreenDisplacementInX:(float)xTranslation inY:(float)yTranslation;
{
    // Translate the model by the accumulated amount
	float currentScaleFactor = sqrt(pow(currentCalculatedMatrix.m11, 2.0f) + pow(currentCalculatedMatrix.m12, 2.0f) + pow(currentCalculatedMatrix.m13, 2.0f));	
	
	xTranslation = xTranslation * [[UIScreen mainScreen] scale] / (currentScaleFactor * currentScaleFactor * backingWidth * 0.5);
	yTranslation = yTranslation * [[UIScreen mainScreen] scale] / (currentScaleFactor * currentScaleFactor * backingWidth * 0.5);
    
	// Use the (0,4,8) components to figure the eye's X axis in the model coordinate system, translate along that
	// Use the (1,5,9) components to figure the eye's Y axis in the model coordinate system, translate along that
	
    accumulatedModelTranslation[0] += xTranslation * currentCalculatedMatrix.m11 + yTranslation * currentCalculatedMatrix.m12;
    accumulatedModelTranslation[1] += xTranslation * currentCalculatedMatrix.m21 + yTranslation * currentCalculatedMatrix.m22;
    accumulatedModelTranslation[2] += xTranslation * currentCalculatedMatrix.m31 + yTranslation * currentCalculatedMatrix.m32;
}

- (void)resetModelViewMatrix;
{
    [super resetModelViewMatrix];
    
    accumulatedModelTranslation[0] = 0.0;
    accumulatedModelTranslation[1] = 0.0;
    accumulatedModelTranslation[2] = 0.0;
}

#pragma mark -
#pragma mark OpenGL drawing support

- (void)loadOrthoMatrix:(GLfloat *)matrix left:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top near:(GLfloat)near far:(GLfloat)far;
{
    GLfloat r_l = right - left;
    GLfloat t_b = top - bottom;
    GLfloat f_n = far - near;
    
    matrix[0] = 2.0f / r_l;
    matrix[1] = 0.0f;
    matrix[2] = 0.0f;
    
    matrix[3] = 0.0f;
    matrix[4] = 2.0f / t_b;
    matrix[5] = 0.0f;
    
    matrix[6] = 0.0f;
    matrix[7] = 0.0f;
    matrix[8] = 2.0f / f_n;
    
    [sphereDepthProgram use];
    glUniformMatrix3fv(sphereDepthOrthographicMatrix, 1, 0, orthographicMatrix);

    [sphereDepthWriteProgram use];
    glUniformMatrix3fv(sphereDepthWriteOrthographicMatrix, 1, 0, orthographicMatrix);

    [cylinderDepthProgram use];
    glUniformMatrix3fv(cylinderDepthOrthographicMatrix, 1, 0, orthographicMatrix);

    [sphereRaytracingProgram use];
    glUniformMatrix3fv(sphereRaytracingOrthographicMatrix, 1, 0, orthographicMatrix);

    [cylinderRaytracingProgram use];
    glUniformMatrix3fv(cylinderRaytracingOrthographicMatrix, 1, 0, orthographicMatrix);
    
    [sphereAmbientOcclusionProgram use];
    glUniformMatrix3fv(sphereAmbientOcclusionOrthographicMatrix, 1, 0, orthographicMatrix);

    [cylinderAmbientOcclusionProgram use];
    glUniformMatrix3fv(cylinderAmbientOcclusionOrthographicMatrix, 1, 0, orthographicMatrix);

}

- (BOOL)createFramebuffersForLayer:(CAEAGLLayer *)glLayer;
{
    dispatch_async(openGLESContextQueue, ^{
        [EAGLContext setCurrentContext:context];
        
        // Need this to make the layer dimensions an even multiple of 32 for performance reasons
        // Also, the 4.2 Simulator will not display the frame otherwise
        /*	CGRect layerBounds = glLayer.bounds;
         CGFloat newWidth = (CGFloat)((int)layerBounds.size.width / 32) * 32.0f;
         CGFloat newHeight = (CGFloat)((int)layerBounds.size.height / 32) * 32.0f;
         
         NSLog(@"Bounds before: %@", NSStringFromCGRect(glLayer.bounds));
         
         glLayer.bounds = CGRectMake(layerBounds.origin.x, layerBounds.origin.y, newWidth, newHeight);
         
         NSLog(@"Bounds after: %@", NSStringFromCGRect(glLayer.bounds));
         */
        glEnable(GL_TEXTURE_2D);
        
        [self createFramebuffer:&viewFramebuffer size:CGSizeZero renderBuffer:&viewRenderbuffer depthBuffer:&viewDepthBuffer texture:NULL layer:glLayer];    
        //    [self createFramebuffer:&depthPassFramebuffer size:CGSizeMake(backingWidth, backingHeight) renderBuffer:&depthPassRenderbuffer depthBuffer:&depthPassDepthBuffer texture:&depthPassTexture layer:glLayer];
        [self createFramebuffer:&depthPassFramebuffer size:CGSizeMake(backingWidth, backingHeight) renderBuffer:NULL depthBuffer:&depthPassDepthBuffer texture:&depthPassTexture layer:glLayer];

        if (!ambientOcclusionFramebuffer)
        {
            [self createFramebuffer:&ambientOcclusionFramebuffer size:CGSizeMake(ambientOcclusionTextureWidth, ambientOcclusionTextureWidth) renderBuffer:NULL depthBuffer:NULL texture:&ambientOcclusionTexture layer:glLayer];                
        }
        
        if (!sphereAOLookupFramebuffer)
        {
            [self createFramebuffer:&sphereAOLookupFramebuffer size:CGSizeMake(ambientOcclusionLookupTextureWidth, ambientOcclusionLookupTextureWidth) renderBuffer:NULL depthBuffer:NULL texture:&sphereAOLookupTexture layer:glLayer];
        }

        [self switchToDisplayFramebuffer];
        glViewport(0, 0, backingWidth, backingHeight);
        
        currentViewportSize = CGSizeMake(backingWidth, backingHeight);
        
        //    [self loadOrthoMatrix:orthographicMatrix left:-1.0 right:1.0 bottom:(-1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) top:(1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) near:-3.0 far:3.0];
        //    [self loadOrthoMatrix:orthographicMatrix left:-1.0 right:1.0 bottom:(-1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) top:(1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) near:-2.0 far:2.0];
        //    [self loadOrthoMatrix:orthographicMatrix left:-1.0 right:1.0 bottom:(-1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) top:(1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) near:-0.5 far:0.5];
        [self loadOrthoMatrix:orthographicMatrix left:-1.0 right:1.0 bottom:(-1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) top:(1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) near:-1.0 far:1.0];
        
        // 0 - Depth pass texture
        // 1 - Ambient occlusion texture
        // 2 - AO lookup texture
        // 3 - Sphere depth precalculation texture

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, depthPassTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, ambientOcclusionTexture);

        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, sphereAOLookupTexture);

        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, sphereDepthMappingTexture);
    });
    
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
        if ( (ambientOcclusionTexture == 0) || (*backingTexturePointer != ambientOcclusionTexture))
        {
            if (*backingTexturePointer != 0)
            {
                glDeleteTextures(1, backingTexturePointer);
            }
            
            glGenTextures(1, backingTexturePointer);

            glBindTexture(GL_TEXTURE_2D, *backingTexturePointer);
            if (*backingTexturePointer == ambientOcclusionTexture)
            {
//                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
//                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE);
//                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);


                
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferSize.width, bufferSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
//                glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, bufferSize.width, bufferSize.height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0);
            }
            else if (*backingTexturePointer == sphereAOLookupTexture)
            {
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
//                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
//                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE);
                
                
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferSize.width, bufferSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
            }
            else
            {
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
//                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
//                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE);

                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferSize.width, bufferSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
            }            
        }
        else
        {
            glBindTexture(GL_TEXTURE_2D, *backingTexturePointer);
        }
        
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

- (void)initializeDepthShaders;
{
    if (sphereDepthProgram != nil)
    {
        return;
    }

    [EAGLContext setCurrentContext:context];
    
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
		sphereDepthProgram = nil;
	}
    
    sphereDepthPositionAttribute = [sphereDepthProgram attributeIndex:@"position"];
    sphereDepthImpostorSpaceAttribute = [sphereDepthProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
	sphereDepthModelViewMatrix = [sphereDepthProgram uniformIndex:@"modelViewProjMatrix"];
    sphereDepthRadius = [sphereDepthProgram uniformIndex:@"sphereRadius"];
    sphereDepthOrthographicMatrix = [sphereDepthProgram uniformIndex:@"orthographicMatrix"];
    sphereDepthPrecalculatedDepthTexture = [sphereDepthProgram uniformIndex:@"precalculatedSphereDepthTexture"];
    sphereDepthTranslation = [sphereDepthProgram uniformIndex:@"translation"];
    sphereDepthMapTexture = [sphereDepthProgram uniformIndex:@"sphereDepthMap"];

    [sphereDepthProgram use];
    glEnableVertexAttribArray(sphereDepthPositionAttribute);
    glEnableVertexAttribArray(sphereDepthImpostorSpaceAttribute);

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
		cylinderDepthProgram = nil;
	}
    
    cylinderDepthPositionAttribute = [cylinderDepthProgram attributeIndex:@"position"];
    cylinderDepthDirectionAttribute = [cylinderDepthProgram attributeIndex:@"direction"];
    cylinderDepthImpostorSpaceAttribute = [cylinderDepthProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
	cylinderDepthModelViewMatrix = [cylinderDepthProgram uniformIndex:@"modelViewProjMatrix"];
    cylinderDepthRadius = [cylinderDepthProgram uniformIndex:@"cylinderRadius"];
    cylinderDepthOrthographicMatrix = [cylinderDepthProgram uniformIndex:@"orthographicMatrix"];
    cylinderDepthTranslation = [cylinderDepthProgram uniformIndex:@"translation"];
    
    [cylinderDepthProgram use];
    glEnableVertexAttribArray(cylinderDepthPositionAttribute);
    glEnableVertexAttribArray(cylinderDepthDirectionAttribute);
    glEnableVertexAttribArray(cylinderDepthImpostorSpaceAttribute);

    sphereDepthWriteProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"SphereDepthWrite" fragmentShaderFilename:@"SphereDepthWrite"];
	[sphereDepthWriteProgram addAttribute:@"position"];
	[sphereDepthWriteProgram addAttribute:@"inputImpostorSpaceCoordinate"];
	if (![sphereDepthWriteProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [sphereDepthWriteProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [sphereDepthWriteProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [sphereDepthWriteProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		sphereDepthWriteProgram = nil;
	}
    
    sphereDepthWritePositionAttribute = [sphereDepthWriteProgram attributeIndex:@"position"];
    sphereDepthWriteImpostorSpaceAttribute = [sphereDepthWriteProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
	sphereDepthWriteModelViewMatrix = [sphereDepthWriteProgram uniformIndex:@"modelViewProjMatrix"];
    sphereDepthWriteRadius = [sphereDepthWriteProgram uniformIndex:@"sphereRadius"];
    sphereDepthWriteOrthographicMatrix = [sphereDepthWriteProgram uniformIndex:@"orthographicMatrix"];
    sphereDepthWriteTranslation = [sphereDepthWriteProgram uniformIndex:@"translation"];
    
    [sphereDepthWriteProgram use];
    glEnableVertexAttribArray(sphereDepthWritePositionAttribute);
    glEnableVertexAttribArray(sphereDepthWriteImpostorSpaceAttribute);    
}

- (void)initializeAmbientOcclusionShaders;
{
    if (sphereAmbientOcclusionProgram != nil)
    {
        return;
    }

    [EAGLContext setCurrentContext:context];
    
    sphereAmbientOcclusionProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"SphereAmbientOcclusion" fragmentShaderFilename:@"SphereAmbientOcclusion"];
	[sphereAmbientOcclusionProgram addAttribute:@"position"];
	[sphereAmbientOcclusionProgram addAttribute:@"inputImpostorSpaceCoordinate"];
    [sphereAmbientOcclusionProgram addAttribute:@"ambientOcclusionTextureOffset"];
	if (![sphereAmbientOcclusionProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [sphereAmbientOcclusionProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [sphereAmbientOcclusionProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [sphereAmbientOcclusionProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		sphereAmbientOcclusionProgram = nil;
	}
    
    sphereAmbientOcclusionPositionAttribute = [sphereAmbientOcclusionProgram attributeIndex:@"position"];
    sphereAmbientOcclusionImpostorSpaceAttribute = [sphereAmbientOcclusionProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
    sphereAmbientOcclusionAOOffsetAttribute = [sphereAmbientOcclusionProgram attributeIndex:@"ambientOcclusionTextureOffset"];
	sphereAmbientOcclusionModelViewMatrix = [sphereAmbientOcclusionProgram uniformIndex:@"modelViewProjMatrix"];
    sphereAmbientOcclusionRadius = [sphereAmbientOcclusionProgram uniformIndex:@"sphereRadius"];
    sphereAmbientOcclusionDepthTexture = [sphereAmbientOcclusionProgram uniformIndex:@"depthTexture"];
    sphereAmbientOcclusionOrthographicMatrix = [sphereAmbientOcclusionProgram uniformIndex:@"orthographicMatrix"];
    sphereAmbientOcclusionPrecalculatedDepthTexture = [sphereAmbientOcclusionProgram uniformIndex:@"precalculatedSphereDepthTexture"];
    sphereAmbientOcclusionInverseModelViewMatrix = [sphereAmbientOcclusionProgram uniformIndex:@"inverseModelViewProjMatrix"];
    sphereAmbientOcclusionTexturePatchWidth = [sphereAmbientOcclusionProgram uniformIndex:@"ambientOcclusionTexturePatchWidth"];
    sphereAmbientOcclusionIntensityFactor = [sphereAmbientOcclusionProgram uniformIndex:@"intensityFactor"];
    
    [sphereAmbientOcclusionProgram use];
    glEnableVertexAttribArray(sphereAmbientOcclusionPositionAttribute);
    glEnableVertexAttribArray(sphereAmbientOcclusionImpostorSpaceAttribute);
    glEnableVertexAttribArray(sphereAmbientOcclusionAOOffsetAttribute);
    
    cylinderAmbientOcclusionProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"CylinderAmbientOcclusion" fragmentShaderFilename:@"CylinderAmbientOcclusion"];
	[cylinderAmbientOcclusionProgram addAttribute:@"position"];
	[cylinderAmbientOcclusionProgram addAttribute:@"direction"];
	[cylinderAmbientOcclusionProgram addAttribute:@"inputImpostorSpaceCoordinate"];
    [cylinderAmbientOcclusionProgram addAttribute:@"ambientOcclusionTextureOffset"];
	if (![cylinderAmbientOcclusionProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [cylinderAmbientOcclusionProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [cylinderAmbientOcclusionProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [cylinderAmbientOcclusionProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		cylinderAmbientOcclusionProgram = nil;
	}
    
    cylinderAmbientOcclusionPositionAttribute = [cylinderAmbientOcclusionProgram attributeIndex:@"position"];
    cylinderAmbientOcclusionDirectionAttribute = [cylinderAmbientOcclusionProgram attributeIndex:@"direction"];
    cylinderAmbientOcclusionImpostorSpaceAttribute = [cylinderAmbientOcclusionProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
    cylinderAmbientOcclusionAOOffsetAttribute = [cylinderAmbientOcclusionProgram attributeIndex:@"ambientOcclusionTextureOffset"];
	cylinderAmbientOcclusionModelViewMatrix = [cylinderAmbientOcclusionProgram uniformIndex:@"modelViewProjMatrix"];
    cylinderAmbientOcclusionRadius = [cylinderAmbientOcclusionProgram uniformIndex:@"cylinderRadius"];
    cylinderAmbientOcclusionDepthTexture = [cylinderAmbientOcclusionProgram uniformIndex:@"depthTexture"];
    cylinderAmbientOcclusionOrthographicMatrix = [cylinderAmbientOcclusionProgram uniformIndex:@"orthographicMatrix"];
    cylinderAmbientOcclusionInverseModelViewMatrix = [cylinderAmbientOcclusionProgram uniformIndex:@"inverseModelViewProjMatrix"];
    cylinderAmbientOcclusionTexturePatchWidth = [cylinderAmbientOcclusionProgram uniformIndex:@"ambientOcclusionTexturePatchWidth"];
    cylinderAmbientOcclusionIntensityFactor = [cylinderAmbientOcclusionProgram uniformIndex:@"intensityFactor"];
    
    [cylinderAmbientOcclusionProgram use];
    glEnableVertexAttribArray(cylinderAmbientOcclusionPositionAttribute);
    glEnableVertexAttribArray(cylinderAmbientOcclusionDirectionAttribute);
    glEnableVertexAttribArray(cylinderAmbientOcclusionImpostorSpaceAttribute);
    glEnableVertexAttribArray(cylinderAmbientOcclusionAOOffsetAttribute);
}

- (void)initializeRaytracingShaders;
{
    if (sphereRaytracingProgram != nil)
    {
        return;
    }

    [EAGLContext setCurrentContext:context];

    sphereRaytracingProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"SphereRaytracing" fragmentShaderFilename:@"SphereRaytracing"];
	[sphereRaytracingProgram addAttribute:@"position"];
	[sphereRaytracingProgram addAttribute:@"inputImpostorSpaceCoordinate"];
    [sphereRaytracingProgram addAttribute:@"ambientOcclusionTextureOffset"];
	if (![sphereRaytracingProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [sphereRaytracingProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [sphereRaytracingProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [sphereRaytracingProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		sphereRaytracingProgram = nil;
	}
    
    sphereRaytracingPositionAttribute = [sphereRaytracingProgram attributeIndex:@"position"];
    sphereRaytracingImpostorSpaceAttribute = [sphereRaytracingProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
    sphereRaytracingAOOffsetAttribute = [sphereRaytracingProgram attributeIndex:@"ambientOcclusionTextureOffset"];
	sphereRaytracingModelViewMatrix = [sphereRaytracingProgram uniformIndex:@"modelViewProjMatrix"];
    sphereRaytracingLightPosition = [sphereRaytracingProgram uniformIndex:@"lightPosition"];
    sphereRaytracingRadius = [sphereRaytracingProgram uniformIndex:@"sphereRadius"];
    sphereRaytracingColor = [sphereRaytracingProgram uniformIndex:@"sphereColor"];
    sphereRaytracingDepthTexture = [sphereRaytracingProgram uniformIndex:@"depthTexture"];
    sphereRaytracingOrthographicMatrix = [sphereRaytracingProgram uniformIndex:@"orthographicMatrix"];
    sphereRaytracingPrecalculatedDepthTexture = [sphereRaytracingProgram uniformIndex:@"precalculatedSphereDepthTexture"];
    sphereRaytracingInverseModelViewMatrix = [sphereRaytracingProgram uniformIndex:@"inverseModelViewProjMatrix"];
    sphereRaytracingTexturePatchWidth = [sphereRaytracingProgram uniformIndex:@"ambientOcclusionTexturePatchWidth"];
    sphereRaytracingAOTexture = [sphereRaytracingProgram uniformIndex:@"ambientOcclusionTexture"];
    sphereRaytracingPrecalculatedAOLookupTexture = [sphereRaytracingProgram uniformIndex:@"precalculatedAOLookupTexture"];
    sphereRaytracingTranslation = [sphereRaytracingProgram uniformIndex:@"translation"];
    sphereRaytracingDepthMapTexture = [sphereRaytracingProgram uniformIndex:@"sphereDepthMap"];

    [sphereRaytracingProgram use];
    glEnableVertexAttribArray(sphereRaytracingPositionAttribute);
    glEnableVertexAttribArray(sphereRaytracingImpostorSpaceAttribute);
    glEnableVertexAttribArray(sphereRaytracingAOOffsetAttribute);

    cylinderRaytracingProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"CylinderRaytracing" fragmentShaderFilename:@"CylinderRaytracing"];
	[cylinderRaytracingProgram addAttribute:@"position"];
	[cylinderRaytracingProgram addAttribute:@"direction"];
	[cylinderRaytracingProgram addAttribute:@"inputImpostorSpaceCoordinate"];
    [cylinderRaytracingProgram addAttribute:@"ambientOcclusionTextureOffset"];

	if (![cylinderRaytracingProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [cylinderRaytracingProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [cylinderRaytracingProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [cylinderRaytracingProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		cylinderRaytracingProgram = nil;
	}
    
    cylinderRaytracingPositionAttribute = [cylinderRaytracingProgram attributeIndex:@"position"];
    cylinderRaytracingDirectionAttribute = [cylinderRaytracingProgram attributeIndex:@"direction"];
    cylinderRaytracingImpostorSpaceAttribute = [cylinderRaytracingProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
    cylinderRaytracingAOOffsetAttribute = [cylinderRaytracingProgram attributeIndex:@"ambientOcclusionTextureOffset"];
	cylinderRaytracingModelViewMatrix = [cylinderRaytracingProgram uniformIndex:@"modelViewProjMatrix"];
    cylinderRaytracingLightPosition = [cylinderRaytracingProgram uniformIndex:@"lightPosition"];
    cylinderRaytracingRadius = [cylinderRaytracingProgram uniformIndex:@"cylinderRadius"];
    cylinderRaytracingColor = [cylinderRaytracingProgram uniformIndex:@"cylinderColor"];
    cylinderRaytracingDepthTexture = [cylinderRaytracingProgram uniformIndex:@"depthTexture"];
    cylinderRaytracingOrthographicMatrix = [cylinderRaytracingProgram uniformIndex:@"orthographicMatrix"];
    cylinderRaytracingInverseModelViewMatrix = [cylinderRaytracingProgram uniformIndex:@"inverseModelViewProjMatrix"];
    cylinderRaytracingTexturePatchWidth = [cylinderRaytracingProgram uniformIndex:@"ambientOcclusionTexturePatchWidth"];
    cylinderRaytracingAOTexture = [cylinderRaytracingProgram uniformIndex:@"ambientOcclusionTexture"];
    cylinderRaytracingTranslation = [cylinderRaytracingProgram uniformIndex:@"translation"];
    
    [cylinderRaytracingProgram use];
    glEnableVertexAttribArray(cylinderRaytracingPositionAttribute);
    glEnableVertexAttribArray(cylinderRaytracingImpostorSpaceAttribute);
    glEnableVertexAttribArray(cylinderRaytracingAOOffsetAttribute);
    glEnableVertexAttribArray(cylinderRaytracingDirectionAttribute);

#ifdef ENABLETEXTUREDISPLAYDEBUGGING
    passthroughProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"PlainDisplay" fragmentShaderFilename:@"PlainDisplay"];
	[passthroughProgram addAttribute:@"position"];
	[passthroughProgram addAttribute:@"inputTextureCoordinate"];
    
    if (![passthroughProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [passthroughProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [passthroughProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [passthroughProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		passthroughProgram = nil;
	}
    
    passthroughPositionAttribute = [passthroughProgram attributeIndex:@"position"];
    passthroughTextureCoordinateAttribute = [passthroughProgram attributeIndex:@"inputTextureCoordinate"];
    passthroughTexture = [passthroughProgram uniformIndex:@"texture"];

    [passthroughProgram use];    
	glEnableVertexAttribArray(passthroughPositionAttribute);
	glEnableVertexAttribArray(passthroughTextureCoordinateAttribute);

#endif
    
    
    sphereAOLookupPrecalculationProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"SphereAOLookup" fragmentShaderFilename:@"SphereAOLookup"];
	[sphereAOLookupPrecalculationProgram addAttribute:@"inputImpostorSpaceCoordinate"];
	if (![sphereAOLookupPrecalculationProgram link])
	{
		NSLog(@"Raytracing shader link failed");
		NSString *progLog = [sphereAOLookupPrecalculationProgram programLog];
		NSLog(@"Program Log: %@", progLog); 
		NSString *fragLog = [sphereAOLookupPrecalculationProgram fragmentShaderLog];
		NSLog(@"Frag Log: %@", fragLog);
		NSString *vertLog = [sphereAOLookupPrecalculationProgram vertexShaderLog];
		NSLog(@"Vert Log: %@", vertLog);
		sphereAOLookupPrecalculationProgram = nil;
	}
    
    sphereAOLookupImpostorSpaceAttribute = [sphereAOLookupPrecalculationProgram attributeIndex:@"inputImpostorSpaceCoordinate"];
    sphereAOLookupPrecalculatedDepthTexture = [sphereAOLookupPrecalculationProgram uniformIndex:@"precalculatedSphereDepthTexture"];
    sphereAOLookupInverseModelViewMatrix = [sphereAOLookupPrecalculationProgram uniformIndex:@"inverseModelViewProjMatrix"];

    [sphereAOLookupPrecalculationProgram use];
    glEnableVertexAttribArray(sphereAOLookupImpostorSpaceAttribute);
    
    [self generateSphereDepthMapTexture];
    
//    glDisable(GL_DEPTH_TEST); 
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glDisable(GL_ALPHA_TEST); 
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_ONE, GL_ONE);

    glEnable(GL_CULL_FACE);
	glCullFace(GL_BACK);

//    glAlphaFunc(GL_ALWAYS, 0);
//    glDepthMask(GL_FALSE);
}

- (void)switchToDisplayFramebuffer;
{
	glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);

    CGSize newViewportSize = CGSizeMake(backingWidth, backingHeight);

    if (!CGSizeEqualToSize(newViewportSize, currentViewportSize))
    {        
        glViewport(0, 0, backingWidth, backingHeight);
        currentViewportSize = newViewportSize;
    }
}

- (void)switchToDepthPassFramebuffer;
{
	glBindFramebuffer(GL_FRAMEBUFFER, depthPassFramebuffer);
    
    CGSize newViewportSize = CGSizeMake(backingWidth, backingHeight);
    
    if (!CGSizeEqualToSize(newViewportSize, currentViewportSize))
    {        
        glViewport(0, 0, backingWidth, backingHeight);
        currentViewportSize = newViewportSize;
    }
}

- (void)switchToAmbientOcclusionFramebuffer;
{
	glBindFramebuffer(GL_FRAMEBUFFER, ambientOcclusionFramebuffer);
    
    CGSize newViewportSize = CGSizeMake(ambientOcclusionTextureWidth, ambientOcclusionTextureWidth);
    
    if (!CGSizeEqualToSize(newViewportSize, currentViewportSize))
    {        
        glViewport(0, 0, ambientOcclusionTextureWidth, ambientOcclusionTextureWidth);
        currentViewportSize = newViewportSize;
    }
}

- (void)switchToAOLookupFramebuffer;
{
	glBindFramebuffer(GL_FRAMEBUFFER, sphereAOLookupFramebuffer);
    
    CGSize newViewportSize = CGSizeMake(ambientOcclusionLookupTextureWidth, ambientOcclusionLookupTextureWidth);
    
    if (!CGSizeEqualToSize(newViewportSize, currentViewportSize))
    {        
        glViewport(0, 0, ambientOcclusionLookupTextureWidth, ambientOcclusionLookupTextureWidth);
        currentViewportSize = newViewportSize;
    }
}

- (void)generateSphereDepthMapTexture;
{
//    CFTimeInterval previousTimestamp = CFAbsoluteTimeGetCurrent();

    // Luminance for depth: This takes only 95 ms on an iPad 1, so it's worth it for the 8% - 18% per-frame speedup 
    // Full lighting precalculation: This only takes 264 ms on an iPad 1
    
    unsigned char *sphereDepthTextureData = (unsigned char *)malloc(sphereDepthTextureWidth * sphereDepthTextureWidth * 4);

    glGenTextures(1, &sphereDepthMappingTexture);

    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, sphereDepthMappingTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
//	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//    glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);
        
    for (unsigned int currentColumnInTexture = 0; currentColumnInTexture < sphereDepthTextureWidth; currentColumnInTexture++)
    {
        float normalizedYLocation = -1.0 + 2.0 * (float)currentColumnInTexture / (float)sphereDepthTextureWidth;
        for (unsigned int currentRowInTexture = 0; currentRowInTexture < sphereDepthTextureWidth; currentRowInTexture++)
        {
            float normalizedXLocation = -1.0 + 2.0 * (float)currentRowInTexture / (float)sphereDepthTextureWidth;
            unsigned char currentDepthByte = 0, currentAmbientLightingByte = 0, currentSpecularLightingByte = 0, alphaByte = 0;
            
            float distanceFromCenter = sqrt(normalizedXLocation * normalizedXLocation + normalizedYLocation * normalizedYLocation);
            float currentSphereDepth = 0.0;
            float lightingNormalX = normalizedXLocation, lightingNormalY = normalizedYLocation;
            
            if (distanceFromCenter <= 1.0)
            {
                // First, calculate the depth of the sphere at this point
                currentSphereDepth = sqrt(1.0 - distanceFromCenter * distanceFromCenter);
                currentDepthByte = round(255.0 * currentSphereDepth);
                                
                alphaByte = 255;
            }
            else
            {
                float normalizationFactor = sqrt(normalizedXLocation * normalizedXLocation + normalizedYLocation * normalizedYLocation);
                lightingNormalX = lightingNormalX / normalizationFactor;
                lightingNormalY = lightingNormalY / normalizationFactor;
            }
            
            // Then, do the ambient lighting factor
            float dotProductForLighting = lightingNormalX * lightDirection[0] + lightingNormalY * lightDirection[1] + currentSphereDepth * lightDirection[2];
            if (dotProductForLighting < 0.0)
            {
                dotProductForLighting = 0.0;
            }
            else if (dotProductForLighting > 1.0)
            {
                dotProductForLighting = 1.0;
            }
            
//            float ambientLightingProduct = dotProductForLighting + 0.4;
//            ambientLightingProduct = MIN(1.0, ambientLightingProduct);
            
            currentAmbientLightingByte = round(255.0 * dotProductForLighting);
            
            // Finally, do the specular lighting factor
            float specularIntensity = pow(dotProductForLighting, 40.0);
//            currentSpecularLightingByte = round(255.0 * specularIntensity * 0.48);
//            currentSpecularLightingByte = round(255.0 * specularIntensity * 0.6);
            currentSpecularLightingByte = round(255.0 * specularIntensity * 0.5);

            sphereDepthTextureData[currentColumnInTexture * sphereDepthTextureWidth * 4 + (currentRowInTexture * 4)] = currentDepthByte;
            sphereDepthTextureData[currentColumnInTexture * sphereDepthTextureWidth * 4 + (currentRowInTexture * 4) + 1] = currentAmbientLightingByte;
            sphereDepthTextureData[currentColumnInTexture * sphereDepthTextureWidth * 4 + (currentRowInTexture * 4) + 2] = currentSpecularLightingByte;            
            sphereDepthTextureData[currentColumnInTexture * sphereDepthTextureWidth * 4 + (currentRowInTexture * 4) + 3] = alphaByte;
/*            
            float lightingIntensity = 0.2 + 1.3 * clamp(dot(lightPosition, normal), 0.0, 1.0) * ambientOcclusionIntensity.r;
            finalSphereColor *= lightingIntensity;
            
            // Per fragment specular lighting
            lightingIntensity  = clamp(dot(lightPosition, normal), 0.0, 1.0);
            lightingIntensity  = pow(lightingIntensity, 60.0) * ambientOcclusionIntensity.r * 1.2;
            finalSphereColor += vec3(0.4, 0.4, 0.4) * lightingIntensity + vec3(1.0, 1.0, 1.0) * 0.2 * ambientOcclusionIntensity.r;
*/
            
        }
    }
    
//	glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, sphereDepthTextureWidth, sphereDepthTextureWidth, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, sphereDepthTextureData);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, sphereDepthTextureWidth, sphereDepthTextureWidth, 0, GL_RGBA, GL_UNSIGNED_BYTE, sphereDepthTextureData);
    glGenerateMipmap(GL_TEXTURE_2D);
//    glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE);

    free(sphereDepthTextureData);
    
//    CFTimeInterval frameDuration = CFAbsoluteTimeGetCurrent() - previousTimestamp;
    
//    NSLog(@"Texture generation duration: %f ms", frameDuration * 1000.0);

}

- (void)destroyFramebuffers;
{
    dispatch_async(openGLESContextQueue, ^{
        [EAGLContext setCurrentContext:context];

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

        if (depthPassFramebuffer)
        {
            glDeleteFramebuffers(1, &depthPassFramebuffer);
            depthPassFramebuffer = 0;
        }
        
        if (depthPassDepthBuffer)
        {
            glDeleteRenderbuffers(1, &depthPassDepthBuffer);
            depthPassDepthBuffer = 0;
        }

        if (depthPassTexture)
        {
            glDeleteTextures(1, &depthPassTexture);
            depthPassTexture = 0;
        }

    });   
}

- (void)configureProjection;
{
    [self loadOrthoMatrix:orthographicMatrix left:-1.0 right:1.0 bottom:(-1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) top:(1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) near:-1.0 far:1.0];
}

- (void)presentRenderBuffer;
{
   [context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)clearScreen;
{
    dispatch_async(openGLESContextQueue, ^{
        [EAGLContext setCurrentContext:context];
        
        [self switchToDisplayFramebuffer];
        
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        [self presentRenderBuffer];
    });
}

- (void)suspendRenderingDuringRotation;
{
    dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)resumeRenderingDuringRotation;
{
    dispatch_semaphore_signal(frameRenderingSemaphore);
}

#pragma mark -
#pragma mark Actual OpenGL rendering

- (void)renderFrameForMolecule:(SLSMolecule *)molecule;
{
    if (!isSceneReady)
    {
        return;
    }

    // In order to prevent frames to be rendered from building up indefinitely, we use a dispatch semaphore to keep at most two frames in the queue
    
    if (dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        return;
    }
    
    dispatch_async(openGLESContextQueue, ^{
        
        [EAGLContext setCurrentContext:context];

//        CFTimeInterval previousTimestamp = CFAbsoluteTimeGetCurrent();
        
        GLfloat currentModelViewMatrix[9];
        [self convert3DTransform:&currentCalculatedMatrix to3x3Matrix:currentModelViewMatrix];
        
        CATransform3D inverseMatrix = CATransform3DInvert(currentCalculatedMatrix);
        GLfloat inverseModelViewMatrix[9];
        [self convert3DTransform:&inverseMatrix to3x3Matrix:inverseModelViewMatrix];

        // Load these once here so that they don't go out of sync between rendering passes during user gestures
        GLfloat currentTranslation[3];
        currentTranslation[0] = accumulatedModelTranslation[0];
        currentTranslation[1] = accumulatedModelTranslation[1];
        currentTranslation[2] = accumulatedModelTranslation[2];
        
        GLfloat currentScaleFactor = currentModelScaleFactor;

        [self precalculateAOLookupTextureForInverseMatrix:inverseModelViewMatrix];
        [self renderDepthTextureForModelViewMatrix:currentModelViewMatrix translation:currentTranslation scale:currentScaleFactor];
//        [self displayTextureToScreen:sphereAOLookupTexture];
//        [self displayTextureToScreen:depthPassTexture];
//        [self displayTextureToScreen:ambientOcclusionTexture];
        [self renderRaytracedSceneForModelViewMatrix:currentModelViewMatrix inverseMatrix:inverseModelViewMatrix translation:currentTranslation scale:currentScaleFactor];
        
        const GLenum discards[]  = {GL_DEPTH_ATTACHMENT};
        glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, discards);

        [self presentRenderBuffer];
        
//        CFTimeInterval frameDuration = CFAbsoluteTimeGetCurrent() - previousTimestamp;
//        
//        NSLog(@"Frame duration: %f ms", frameDuration * 1000.0);
        
        dispatch_semaphore_signal(frameRenderingSemaphore);
    });
}

#pragma mark -
#pragma mark Molecule 3-D geometry generation

- (void)configureBasedOnNumberOfAtoms:(unsigned int)numberOfAtoms numberOfBonds:(unsigned int)numberOfBonds;
{
    widthOfAtomAOTexturePatch = (GLfloat)ambientOcclusionTextureWidth / (ceil(sqrt((GLfloat)numberOfAtoms + (GLfloat)numberOfBonds)));
    normalizedAOTexturePatchWidth = (GLfloat)widthOfAtomAOTexturePatch / (GLfloat)ambientOcclusionTextureWidth;
    
    previousAmbientOcclusionOffset[0] = normalizedAOTexturePatchWidth / 2.0;
    previousAmbientOcclusionOffset[1] = normalizedAOTexturePatchWidth / 2.0;
    
    shouldDrawBonds = (numberOfBonds > 0);
}

- (void)addAtomToVertexBuffers:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint;
{
    GLushort baseToAddToIndices = numberOfAtomVertices[atomType];
    
    GLfloat newVertex[3];
    //    newVertex[0] = newPoint.x;
    newVertex[0] = -newPoint.x;
    newVertex[1] = newPoint.y;
    newVertex[2] = newPoint.z;
    
    /*
    // Square coordinate generation
    
    GLfloat lowerLeftTexture[2] = {-1.0, -1.0};
    GLfloat lowerRightTexture[2] = {1.0, -1.0};
    GLfloat upperLeftTexture[2] = {-1.0, 1.0};
    GLfloat upperRightTexture[2] = {1.0, 1.0};
    
    // Add four copies of this vertex, that will be translated in the vertex shader into the billboard
    // Interleave texture coordinates in VBO
    [self addVertex:newVertex forAtomType:atomType];
    [self addTextureCoordinate:lowerLeftTexture forAtomType:atomType];
    [self addAmbientOcclusionTextureOffset:previousAmbientOcclusionOffset forAtomType:atomType];
    [self addVertex:newVertex forAtomType:atomType];
    [self addTextureCoordinate:lowerRightTexture forAtomType:atomType];
    [self addAmbientOcclusionTextureOffset:previousAmbientOcclusionOffset forAtomType:atomType];
    [self addVertex:newVertex forAtomType:atomType];
    [self addTextureCoordinate:upperLeftTexture forAtomType:atomType];
    [self addAmbientOcclusionTextureOffset:previousAmbientOcclusionOffset forAtomType:atomType];
    [self addVertex:newVertex forAtomType:atomType];
    [self addTextureCoordinate:upperRightTexture forAtomType:atomType];
    [self addAmbientOcclusionTextureOffset:previousAmbientOcclusionOffset forAtomType:atomType];
    
    //    123324
    GLushort newIndices[6];
    newIndices[0] = baseToAddToIndices;
    newIndices[1] = baseToAddToIndices + 1;
    newIndices[2] = baseToAddToIndices + 2;
    newIndices[3] = baseToAddToIndices + 2;
    newIndices[4] = baseToAddToIndices + 1;
    newIndices[5] = baseToAddToIndices + 3;

    
    [self addIndices:newIndices size:6 forAtomType:atomType];
*/
     
    
    /*
    // Hexagonal coordinate generation, using raster-optimized layout
    
    GLfloat positiveSideComponent = 2.0 / sqrt(3);
    GLfloat negativeSideComponent = -2.0 / sqrt(3);

    GLfloat hexagonPoints[6][2] = {
        {negativeSideComponent, 1.0},
        {negativeSideComponent, -1.0},
        {1.0, 0.0},
        {positiveSideComponent, 1.0},
        {-1.0, 0.0},
        {positiveSideComponent, -1.0}
    };
    
    for (unsigned int currentTextureCoordinate = 0; currentTextureCoordinate < 6; currentTextureCoordinate++)
    {
        [self addVertex:newVertex forAtomType:atomType];
        [self addTextureCoordinate:hexagonPoints[currentTextureCoordinate] forAtomType:atomType];
        [self addAmbientOcclusionTextureOffset:previousAmbientOcclusionOffset forAtomType:atomType];
    }
    
    // 123,341,152,263
    GLushort newIndices[12];
    newIndices[0] = baseToAddToIndices;
    newIndices[1] = baseToAddToIndices + 1;
    newIndices[2] = baseToAddToIndices + 2;

    newIndices[3] = baseToAddToIndices + 2;
    newIndices[4] = baseToAddToIndices + 3;
    newIndices[5] = baseToAddToIndices;

    newIndices[6] = baseToAddToIndices + 0;
    newIndices[7] = baseToAddToIndices + 4;
    newIndices[8] = baseToAddToIndices + 1;

    newIndices[9] = baseToAddToIndices + 1;
    newIndices[10] = baseToAddToIndices + 5;
    newIndices[11] = baseToAddToIndices + 2;
    
    [self addIndices:newIndices size:12 forAtomType:atomType];
    
    */
    

    // Octagonal coordinate generation, using raster-optimized layout
     GLfloat positiveSideComponent = 1.0 - 2.0 / (sqrt(2) + 2);
     GLfloat negativeSideComponent = -1.0 + 2.0 / (sqrt(2) + 2);
     
     GLfloat octagonPoints[8][2] = {
         {negativeSideComponent, 1.0},
         {-1.0, negativeSideComponent},
         {1.0, positiveSideComponent},
         {positiveSideComponent, -1.0},
         {1.0, negativeSideComponent},
         {positiveSideComponent, 1.0},
         {-1.0, positiveSideComponent},
         {negativeSideComponent, -1.0},
     };
     
     // Add eight copies of this vertex, that will be translated in the vertex shader into the billboard
     // Interleave texture coordinates in VBO
     
     for (unsigned int currentTextureCoordinate = 0; currentTextureCoordinate < 8; currentTextureCoordinate++)
     {
         [self addVertex:newVertex forAtomType:atomType];
         [self addTextureCoordinate:octagonPoints[currentTextureCoordinate] forAtomType:atomType];
         [self addAmbientOcclusionTextureOffset:previousAmbientOcclusionOffset forAtomType:atomType];     
     }

    // 123, 324, 345, 136, 217, 428
    
    GLushort newIndices[18];
    newIndices[0] = baseToAddToIndices;
    newIndices[1] = baseToAddToIndices + 1;
    newIndices[2] = baseToAddToIndices + 2;

    newIndices[3] = baseToAddToIndices + 2;
    newIndices[4] = baseToAddToIndices + 1;
    newIndices[5] = baseToAddToIndices + 3;

    newIndices[6] = baseToAddToIndices + 2;
    newIndices[7] = baseToAddToIndices + 3;
    newIndices[8] = baseToAddToIndices + 4;

    newIndices[9] = baseToAddToIndices;
    newIndices[10] = baseToAddToIndices + 2;
    newIndices[11] = baseToAddToIndices + 5;

    newIndices[12] = baseToAddToIndices + 1;
    newIndices[13] = baseToAddToIndices;
    newIndices[14] = baseToAddToIndices + 6;

    newIndices[15] = baseToAddToIndices + 3;
    newIndices[16] = baseToAddToIndices + 1;
    newIndices[17] = baseToAddToIndices + 7;
     
    [self addIndices:newIndices size:18 forAtomType:atomType];
     
    
     previousAmbientOcclusionOffset[0] += normalizedAOTexturePatchWidth;
    if (previousAmbientOcclusionOffset[0] > (1.0 - normalizedAOTexturePatchWidth * 0.15))
    {
        previousAmbientOcclusionOffset[0] = normalizedAOTexturePatchWidth / 2.0;
        previousAmbientOcclusionOffset[1] += normalizedAOTexturePatchWidth;
    }    
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
    
//    cylinderDirection[0] = endPoint.x - startPoint.x;
    cylinderDirection[0] = startPoint.x - endPoint.x;
    cylinderDirection[1] = endPoint.y - startPoint.y;
    cylinderDirection[2] = endPoint.z - startPoint.z;

    // Impostor space coordinates
    GLfloat lowerLeftTexture[2] = {-1.0, -1.0};
    GLfloat lowerRightTexture[2] = {1.0, -1.0};
    GLfloat upperLeftTexture[2] = {-1.0, 1.0};
    GLfloat upperRightTexture[2] = {1.0, 1.0};

//    newVertex[0] = startPoint.x;
    newVertex[0] = -startPoint.x;
    newVertex[1] = startPoint.y;
    newVertex[2] = startPoint.z;

    [self addBondVertex:newVertex];
    [self addBondDirection:cylinderDirection];
    [self addBondTextureCoordinate:lowerLeftTexture];
    [self addBondAmbientOcclusionTextureOffset:previousAmbientOcclusionOffset];
    [self addBondVertex:newVertex];
    [self addBondDirection:cylinderDirection];
    [self addBondTextureCoordinate:lowerRightTexture];
    [self addBondAmbientOcclusionTextureOffset:previousAmbientOcclusionOffset];
    
//    newVertex[0] = endPoint.x;
    newVertex[0] = -endPoint.x;
    newVertex[1] = endPoint.y;
    newVertex[2] = endPoint.z;
    
    [self addBondVertex:newVertex];
    [self addBondDirection:cylinderDirection];
    [self addBondTextureCoordinate:upperLeftTexture];
    [self addBondAmbientOcclusionTextureOffset:previousAmbientOcclusionOffset];
    [self addBondVertex:newVertex];
    [self addBondDirection:cylinderDirection];
    [self addBondTextureCoordinate:upperRightTexture];
    [self addBondAmbientOcclusionTextureOffset:previousAmbientOcclusionOffset];
    
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
    
    previousAmbientOcclusionOffset[0] += normalizedAOTexturePatchWidth;
    if (previousAmbientOcclusionOffset[0] > (1.0 - normalizedAOTexturePatchWidth * 0.15))
    {
        previousAmbientOcclusionOffset[0] = normalizedAOTexturePatchWidth / 2.0;
        previousAmbientOcclusionOffset[1] += normalizedAOTexturePatchWidth;
    }
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
    if (atomVBOs[atomType] == nil)
    {
        atomVBOs[atomType] = [[NSMutableData alloc] init];
    }
    
	[atomVBOs[atomType] appendBytes:ambientOcclusionOffset length:(sizeof(GLfloat) * 2)];	
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

- (void)addBondAmbientOcclusionTextureOffset:(GLfloat *)ambientOcclusionOffset;
{
    if (bondVBOs[currentBondVBO] == nil)
    {
        bondVBOs[currentBondVBO] = [[NSMutableData alloc] init];
    }
    
	[bondVBOs[currentBondVBO] appendBytes:ambientOcclusionOffset length:(sizeof(GLfloat) * 2)];	
}

#pragma mark -
#pragma mark OpenGL drawing routines

- (void)testPrecisionOfConversionCalculation;
{
    float stepSize = 1.0 / 20.0;
    
    for (float inputFloat = 0.0; inputFloat < 1.0; inputFloat += stepSize)
    {
        float ceilInputFloat = ceil(inputFloat * 765.0) / 765.0;
        
        float blue = MAX(0.0, ceilInputFloat - (2.0 / 3.0));
        float green = MAX(0.0, ceilInputFloat - (1.0 / 3.0) - blue);
        float red = ceilInputFloat - blue - green;
        
        unsigned char blueValue = (unsigned char)(blue * 3.0 * 255.0);
        unsigned char greenValue = (unsigned char)(green * 3.0 * 255.0);
        unsigned char redValue = (unsigned char)(red * 3.0 * 255.0);
        
        float result = ((float)blueValue / 255.0 + (float)greenValue / 255.0 + (float)redValue / 255.0) / 3.0;
        
        NSLog(@"1: Input value: %f, converted value: %f", inputFloat, result);
        
        
        int convertedInput = ceil(inputFloat * 765.0);
        int blueInt = MAX(0, convertedInput - 510);
        int greenInt = MAX(0, convertedInput - 255 - blueInt);
        int redInt = convertedInput - blueInt - greenInt;

        unsigned char blueValue2 = (unsigned char)(blueInt);
        unsigned char greenValue2 = (unsigned char)(greenInt);
        unsigned char redValue2 = (unsigned char)(redInt);
        
        float result2 = ((float)blueValue2 / 255.0 + (float)greenValue2 / 255.0 + (float)redValue2 / 255.0) / 3.0;
        NSLog(@"2: Input value: %f, converted value: %f", inputFloat, result2);

    }
}

- (void)bindVertexBuffersForMolecule;
{
//    [super performSelectorOnMainThread:@selector( bindVertexBuffersForMolecule) withObject:nil waitUntilDone:YES];
    [super bindVertexBuffersForMolecule];
    [self prepareAmbientOcclusionMap];
    
    isSceneReady = YES;
}

- (void)renderDepthTextureForModelViewMatrix:(GLfloat *)depthModelViewMatrix translation:(GLfloat *)modelTranslation scale:(GLfloat)scaleFactor;
{
    [self switchToDepthPassFramebuffer];
    
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
    glBlendEquation(GL_MIN_EXT);
    glDepthMask(GL_TRUE);
    glDepthFunc(GL_LEQUAL);

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [self writeDepthValuesForOpaqueAreasForModelViewMatrix:depthModelViewMatrix translation:modelTranslation scale:scaleFactor];
    glDepthMask(GL_FALSE);

    // Draw the spheres
    [sphereDepthProgram use];
    
    glUniformMatrix3fv(sphereDepthModelViewMatrix, 1, 0, depthModelViewMatrix);
    glUniform3fv(sphereDepthTranslation, 1, modelTranslation);
    glUniform1i(sphereDepthMapTexture, 3);

    float sphereScaleFactor = overallMoleculeScaleFactor * scaleFactor * atomRadiusScaleFactor;
    GLsizei atomVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2 + sizeof(GLfloat) * 2;
    
    for (unsigned int currentAtomType = 0; currentAtomType < NUM_ATOMTYPES; currentAtomType++)
    {
        if (atomIndexBufferHandle[currentAtomType] != 0)
        {
            glUniform1f(sphereDepthRadius, atomProperties[currentAtomType].atomRadius * sphereScaleFactor);

            // Bind the VBO and attach it to the program
            glBindBuffer(GL_ARRAY_BUFFER, atomVertexBufferHandles[currentAtomType]); 
            glVertexAttribPointer(sphereDepthPositionAttribute, 3, GL_FLOAT, 0, atomVBOStride, (char *)NULL + 0);
            glVertexAttribPointer(sphereDepthImpostorSpaceAttribute, 2, GL_FLOAT, 0, atomVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
            
            // Bind the index buffer and draw to the screen
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, atomIndexBufferHandle[currentAtomType]);    
            glDrawElements(GL_TRIANGLES, numberOfIndicesInBuffer[currentAtomType], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }
    }
    
    if (shouldDrawBonds)
    {
        // Draw the cylinders    
        [cylinderDepthProgram use];
        
        float cylinderScaleFactor = overallMoleculeScaleFactor * scaleFactor * bondRadiusScaleFactor;
        GLsizei bondVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2 + sizeof(GLfloat) * 2;
        GLfloat bondRadius = 1.0;
        
        glUniform1f(cylinderDepthRadius, bondRadius * cylinderScaleFactor);
        glUniformMatrix3fv(cylinderDepthModelViewMatrix, 1, 0, depthModelViewMatrix);
        glUniform3fv(cylinderDepthTranslation, 1, modelTranslation);

        for (unsigned int currentBondVBOIndex = 0; currentBondVBOIndex < MAX_BOND_VBOS; currentBondVBOIndex++)
        {
            // Draw bonds next
            if (bondVertexBufferHandle[currentBondVBOIndex] != 0)
            {
                // Bind the VBO and attach it to the program
                glBindBuffer(GL_ARRAY_BUFFER, bondVertexBufferHandle[currentBondVBOIndex]); 
                glVertexAttribPointer(cylinderDepthPositionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + 0);
                glVertexAttribPointer(cylinderDepthDirectionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
                glVertexAttribPointer(cylinderDepthImpostorSpaceAttribute, 2, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 3));
                
                // Bind the index buffer and draw to the screen
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bondIndexBufferHandle[currentBondVBOIndex]);    
                glDrawElements(GL_TRIANGLES, numberOfBondIndicesInBuffer[currentBondVBOIndex], GL_UNSIGNED_SHORT, NULL);
                
                // Unbind the buffers
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
                glBindBuffer(GL_ARRAY_BUFFER, 0); 
            }
        }
    }        

    const GLenum discards[]  = {GL_DEPTH_ATTACHMENT};
    glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, discards);
}

- (void)writeDepthValuesForOpaqueAreasForModelViewMatrix:(GLfloat *)depthModelViewMatrix translation:(GLfloat *)modelTranslation scale:(GLfloat)scaleFactor;
{
    glDisable(GL_BLEND);
        
    // Draw the spheres
    [sphereDepthWriteProgram use];
    
    glUniformMatrix3fv(sphereDepthWriteModelViewMatrix, 1, 0, depthModelViewMatrix);
    glUniform3fv(sphereDepthWriteTranslation, 1, modelTranslation);
    
    float sphereScaleFactor = overallMoleculeScaleFactor * scaleFactor * atomRadiusScaleFactor;
    GLsizei atomVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2 + sizeof(GLfloat) * 2;
    
    for (unsigned int currentAtomType = 0; currentAtomType < NUM_ATOMTYPES; currentAtomType++)
    {
        if (atomIndexBufferHandle[currentAtomType] != 0)
        {
            glUniform1f(sphereDepthWriteRadius, atomProperties[currentAtomType].atomRadius * sphereScaleFactor);
            
            // Bind the VBO and attach it to the program
            glBindBuffer(GL_ARRAY_BUFFER, atomVertexBufferHandles[currentAtomType]); 
            glVertexAttribPointer(sphereDepthWritePositionAttribute, 3, GL_FLOAT, 0, atomVBOStride, (char *)NULL + 0);
            glVertexAttribPointer(sphereDepthWriteImpostorSpaceAttribute, 2, GL_FLOAT, 0, atomVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
            
            // Bind the index buffer and draw to the screen
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, atomIndexBufferHandle[currentAtomType]);    
            glDrawElements(GL_TRIANGLES, numberOfIndicesInBuffer[currentAtomType], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }
    }
     
    glEnable(GL_BLEND);
}

- (void)renderRaytracedSceneForModelViewMatrix:(GLfloat *)raytracingModelViewMatrix inverseMatrix:(GLfloat *)inverseMatrix translation:(GLfloat *)modelTranslation scale:(GLfloat)scaleFactor;
{
    [self switchToDisplayFramebuffer];
    
#ifdef USEWHITEBACKGROUND
    glBlendEquation(GL_MIN_EXT);
    
    //    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);

#else
    glBlendEquation(GL_MAX_EXT);
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
#endif
    
    
    glDepthMask(GL_TRUE);
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glColorMask(0.0, 0.0, 0.0, 0.0);
    [self writeDepthValuesForOpaqueAreasForModelViewMatrix:raytracingModelViewMatrix translation:modelTranslation scale:scaleFactor];
    glColorMask(1.0, 1.0, 1.0, 1.0);
    glDepthMask(GL_FALSE);

//    glClear(GL_COLOR_BUFFER_BIT);
//
    // Draw the spheres
    [sphereRaytracingProgram use];
        
    glUniform3fv(sphereRaytracingLightPosition, 1, lightDirection);
    
    // Load in the depth texture from the previous pass
    glUniform1i(sphereRaytracingDepthTexture, 0);
    glUniform1i(sphereRaytracingAOTexture, 1);
    glUniform1i(sphereRaytracingPrecalculatedAOLookupTexture, 2);

    glUniformMatrix3fv(sphereRaytracingModelViewMatrix, 1, 0, raytracingModelViewMatrix);
    glUniformMatrix3fv(sphereRaytracingInverseModelViewMatrix, 1, 0, inverseMatrix);
    glUniform1f(sphereRaytracingTexturePatchWidth, (normalizedAOTexturePatchWidth - 2.0 / (GLfloat)ambientOcclusionTextureWidth) * 0.5);
    glUniform3fv(sphereRaytracingTranslation, 1, modelTranslation);
    glUniform1i(sphereRaytracingDepthMapTexture, 3);

    float sphereScaleFactor = overallMoleculeScaleFactor * scaleFactor * atomRadiusScaleFactor;
    GLsizei atomVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2 + sizeof(GLfloat) * 2;
    
    for (unsigned int currentAtomType = 0; currentAtomType < NUM_ATOMTYPES; currentAtomType++)
    {
        if (atomIndexBufferHandle[currentAtomType] != 0)
        {
            glUniform1f(sphereRaytracingRadius, atomProperties[currentAtomType].atomRadius * sphereScaleFactor);
            glUniform3f(sphereRaytracingColor, (GLfloat)atomProperties[currentAtomType].redComponent / 255.0f , (GLfloat)atomProperties[currentAtomType].greenComponent / 255.0f, (GLfloat)atomProperties[currentAtomType].blueComponent / 255.0f);

            // Bind the VBO and attach it to the program
            glBindBuffer(GL_ARRAY_BUFFER, atomVertexBufferHandles[currentAtomType]); 
            glVertexAttribPointer(sphereRaytracingPositionAttribute, 3, GL_FLOAT, 0, atomVBOStride, (char *)NULL + 0);
            glVertexAttribPointer(sphereRaytracingImpostorSpaceAttribute, 2, GL_FLOAT, 0, atomVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
            glVertexAttribPointer(sphereRaytracingAOOffsetAttribute, 2, GL_FLOAT, 0, atomVBOStride, (char *)NULL + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 2));
          
            // Bind the index buffer and draw to the screen
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, atomIndexBufferHandle[currentAtomType]);    
            glDrawElements(GL_TRIANGLES, numberOfIndicesInBuffer[currentAtomType], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }
    }
        
    if (shouldDrawBonds)
    {        
        // Draw the cylinders
        [cylinderRaytracingProgram use];
        
        glUniform3fv(cylinderRaytracingLightPosition, 1, lightDirection);
        glUniform1i(cylinderRaytracingDepthTexture, 0);	
        glUniform1i(cylinderRaytracingAOTexture, 1);
        glUniform1f(cylinderRaytracingTexturePatchWidth, normalizedAOTexturePatchWidth - 0.5 / (GLfloat)ambientOcclusionTextureWidth);
        
        float cylinderScaleFactor = overallMoleculeScaleFactor * scaleFactor * bondRadiusScaleFactor;
        GLsizei bondVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2 + sizeof(GLfloat) * 2;
        GLfloat bondRadius = 1.0;
        
        glUniform1f(cylinderRaytracingRadius, bondRadius * cylinderScaleFactor);
        glUniform3f(cylinderRaytracingColor, 0.75, 0.75, 0.75);
        glUniformMatrix3fv(cylinderRaytracingModelViewMatrix, 1, 0, raytracingModelViewMatrix);
        glUniformMatrix3fv(cylinderRaytracingInverseModelViewMatrix, 1, 0, inverseMatrix);
        glUniform3fv(cylinderRaytracingTranslation, 1, modelTranslation);

        
        for (unsigned int currentBondVBOIndex = 0; currentBondVBOIndex < MAX_BOND_VBOS; currentBondVBOIndex++)
        {
            // Draw bonds next
            if (bondVertexBufferHandle[currentBondVBOIndex] != 0)
            {
                
                // Bind the VBO and attach it to the program
                glBindBuffer(GL_ARRAY_BUFFER, bondVertexBufferHandle[currentBondVBOIndex]); 
                glVertexAttribPointer(cylinderRaytracingPositionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + 0);
                glVertexAttribPointer(cylinderRaytracingDirectionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
                glVertexAttribPointer(cylinderRaytracingImpostorSpaceAttribute, 2, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 3));
                glVertexAttribPointer(cylinderRaytracingAOOffsetAttribute, 2, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 2));
                
                // Bind the index buffer and draw to the screen
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bondIndexBufferHandle[currentBondVBOIndex]);
                glDrawElements(GL_TRIANGLES, numberOfBondIndicesInBuffer[currentBondVBOIndex], GL_UNSIGNED_SHORT, NULL);

                // Unbind the buffers
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
                glBindBuffer(GL_ARRAY_BUFFER, 0); 
            }
        }
    }        
    
}

- (void)renderAmbientOcclusionTextureForModelViewMatrix:(GLfloat *)ambientOcclusionModelViewMatrix inverseMatrix:(GLfloat *)inverseMatrix fractionOfTotal:(GLfloat)fractionOfTotal;
{
    [self switchToAmbientOcclusionFramebuffer];    

    glBlendEquation(GL_FUNC_ADD);

    float sphereScaleFactor = overallMoleculeScaleFactor * currentModelScaleFactor * atomRadiusScaleFactor;
    GLsizei atomVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2 + sizeof(GLfloat) * 2;

    // Draw the spheres
    [sphereAmbientOcclusionProgram use];
    
    glUniformMatrix3fv(sphereAmbientOcclusionInverseModelViewMatrix, 1, 0, inverseMatrix);
    
    glUniform1i(sphereAmbientOcclusionDepthTexture, 0);

    glUniformMatrix3fv(sphereAmbientOcclusionModelViewMatrix, 1, 0, ambientOcclusionModelViewMatrix);
    glUniform1f(sphereAmbientOcclusionTexturePatchWidth, normalizedAOTexturePatchWidth);
    glUniform1f(sphereAmbientOcclusionIntensityFactor, fractionOfTotal);
    
    for (unsigned int currentAtomType = 0; currentAtomType < NUM_ATOMTYPES; currentAtomType++)
    {
        if (atomIndexBufferHandle[currentAtomType] != 0)
        {
            glUniform1f(sphereAmbientOcclusionRadius, atomProperties[currentAtomType].atomRadius * sphereScaleFactor);
            
            // Bind the VBO and attach it to the program
            glBindBuffer(GL_ARRAY_BUFFER, atomVertexBufferHandles[currentAtomType]); 
            glVertexAttribPointer(sphereAmbientOcclusionPositionAttribute, 3, GL_FLOAT, 0, atomVBOStride, (char *)NULL + 0);
            glVertexAttribPointer(sphereAmbientOcclusionImpostorSpaceAttribute, 2, GL_FLOAT, 0, atomVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
            glVertexAttribPointer(sphereAmbientOcclusionAOOffsetAttribute, 2, GL_FLOAT, 0, atomVBOStride, (char *)NULL + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 2));
            
            // Bind the index buffer and draw to the screen
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, atomIndexBufferHandle[currentAtomType]);    
            glDrawElements(GL_TRIANGLES, numberOfIndicesInBuffer[currentAtomType], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }
    }
    

    // Draw the cylinders    
    [cylinderAmbientOcclusionProgram use];
    
    glUniformMatrix3fv(cylinderAmbientOcclusionInverseModelViewMatrix, 1, 0, inverseMatrix);

    glUniform1i(cylinderAmbientOcclusionDepthTexture, 0);
    
    float cylinderScaleFactor = overallMoleculeScaleFactor * currentModelScaleFactor * bondRadiusScaleFactor;
    GLsizei bondVBOStride = sizeof(GLfloat) * 3 + sizeof(GLfloat) * 3 + sizeof(GLfloat) * 2 + sizeof(GLfloat) * 2;
	GLfloat bondRadius = 1.0;
    
    glUniform1f(cylinderAmbientOcclusionRadius, bondRadius * cylinderScaleFactor);
    glUniformMatrix3fv(cylinderAmbientOcclusionModelViewMatrix, 1, 0, ambientOcclusionModelViewMatrix);
    glUniform1f(cylinderAmbientOcclusionTexturePatchWidth, normalizedAOTexturePatchWidth);
    glUniform1f(cylinderAmbientOcclusionIntensityFactor, fractionOfTotal);
    
    for (unsigned int currentBondVBOIndex = 0; currentBondVBOIndex < MAX_BOND_VBOS; currentBondVBOIndex++)
    {
        // Draw bonds next
        if (bondVertexBufferHandle[currentBondVBOIndex] != 0)
        {
            // Bind the VBO and attach it to the program
            glBindBuffer(GL_ARRAY_BUFFER, bondVertexBufferHandle[currentBondVBOIndex]); 
            glVertexAttribPointer(cylinderAmbientOcclusionPositionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + 0);
            glVertexAttribPointer(cylinderAmbientOcclusionDirectionAttribute, 3, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3));
            glVertexAttribPointer(cylinderAmbientOcclusionImpostorSpaceAttribute, 2, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 3));
            glVertexAttribPointer(cylinderAmbientOcclusionAOOffsetAttribute, 2, GL_FLOAT, 0, bondVBOStride, (char *)NULL + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 3) + (sizeof(GLfloat) * 2));

            // Bind the index buffer and draw to the screen
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bondIndexBufferHandle[currentBondVBOIndex]);    
            glDrawElements(GL_TRIANGLES, numberOfBondIndicesInBuffer[currentBondVBOIndex], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }
    }        
}

/*
#define AMBIENTOCCLUSIONSAMPLINGPOINTS 6

static float ambientOcclusionRotationAngles[AMBIENTOCCLUSIONSAMPLINGPOINTS][2] = 
{
    {0.0, 0.0},
    {M_PI / 2.0, 0.0},
    {M_PI, 0.0},
    {3.0 * M_PI / 2.0, 0.0},
    {0.0, M_PI / 2.0},
    {0.0, 3.0 * M_PI / 2.0}
};

 */

/*
#define AMBIENTOCCLUSIONSAMPLINGPOINTS 14

static float ambientOcclusionRotationAngles[AMBIENTOCCLUSIONSAMPLINGPOINTS][2] = 
{
    {0.0, 0.0},
    {M_PI / 2.0, 0.0},
    {M_PI, 0.0},
    {3.0 * M_PI / 2.0, 0.0},
    {0.0, M_PI / 2.0},
    {0.0, 3.0 * M_PI / 2.0},
    
    {M_PI / 4.0, M_PI / 4.0},
    {3.0 * M_PI / 4.0, M_PI / 4.0},
    {5.0 * M_PI / 4.0, M_PI / 4.0},
    {7.0 * M_PI / 4.0, M_PI / 4.0},

    {M_PI / 4.0, 7.0 * M_PI / 4.0},
    {3.0 * M_PI / 4.0, 7.0 * M_PI / 4.0},
    {5.0 * M_PI / 4.0, 7.0 * M_PI / 4.0},
    {7.0 * M_PI / 4.0, 7.0 * M_PI / 4.0},
};
*/

#define AMBIENTOCCLUSIONSAMPLINGPOINTS 22

static float ambientOcclusionRotationAngles[AMBIENTOCCLUSIONSAMPLINGPOINTS][2] = 
{
    {0.0, 0.0},
    {M_PI / 2.0, 0.0},
    {M_PI, 0.0},
    {3.0 * M_PI / 2.0, 0.0},
    {0.0, M_PI / 2.0},
    {0.0, 3.0 * M_PI / 2.0},
    
    {M_PI / 4.0, M_PI / 4.0},
    {3.0 * M_PI / 4.0, M_PI / 4.0},
    {5.0 * M_PI / 4.0, M_PI / 4.0},
    {7.0 * M_PI / 4.0, M_PI / 4.0},
    
    {M_PI / 4.0, 7.0 * M_PI / 4.0},
    {3.0 * M_PI / 4.0, 7.0 * M_PI / 4.0},
    {5.0 * M_PI / 4.0, 7.0 * M_PI / 4.0},
    {7.0 * M_PI / 4.0, 7.0 * M_PI / 4.0},
    
    {M_PI / 4.0, 0.0},
    {3.0 * M_PI / 4.0, 0.0},
    {5.0 * M_PI / 4.0, 0.0},
    {7.0 * M_PI / 4.0, 0.0},
    
    {0.0, M_PI / 4.0},
    {0.0, 3.0 * M_PI / 4.0},
    {0.0, 5.0 * M_PI / 4.0},
    {0.0, 7.0 * M_PI / 4.0},
};

/*
#define AMBIENTOCCLUSIONSAMPLINGPOINTS 1

static float ambientOcclusionRotationAngles[AMBIENTOCCLUSIONSAMPLINGPOINTS][2] = 
{
    {0.0, 0.0},
};
 */
 
- (void)prepareAmbientOcclusionMap;
{    
    dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);

    dispatch_sync(openGLESContextQueue, ^{
        [EAGLContext setCurrentContext:context];

        if (isRenderingCancelled)
        {
            dispatch_semaphore_signal(frameRenderingSemaphore);
            return;
        }
        
        // Use bilinear filtering here to smooth out the ambient occlusion shadowing
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, depthPassTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        
        GLfloat zeroTranslation[3] = {0.0, 0.0, 0.0};
        
        
//        CFTimeInterval previousTimestamp = CFAbsoluteTimeGetCurrent();
        
        // Start fresh on the ambient texture
        [self switchToAmbientOcclusionFramebuffer];
        
        BOOL disableAOTextureGeneration = NO;
        
        if (disableAOTextureGeneration)
        {
            glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
            glClear(GL_COLOR_BUFFER_BIT);
        }
        else
        {
            //    glClearColor(0.0f, ambientOcclusionModelViewMatrix[0], 1.0f, 1.0f);
            glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
            glClear(GL_COLOR_BUFFER_BIT);
            
            CATransform3D currentSamplingRotationMatrix;
            GLfloat currentModelViewMatrix[9];
            CATransform3D inverseMatrix;
            GLfloat inverseModelViewMatrix[9];
            
            for (unsigned int currentAOSamplingPoint = 0; currentAOSamplingPoint < AMBIENTOCCLUSIONSAMPLINGPOINTS; currentAOSamplingPoint++)
            {        
                if (isRenderingCancelled)
                {        
                    dispatch_semaphore_signal(frameRenderingSemaphore);
                    return;
                }
                
                float theta = ambientOcclusionRotationAngles[currentAOSamplingPoint][0];
                float phi = ambientOcclusionRotationAngles[currentAOSamplingPoint][1];
                
                currentSamplingRotationMatrix = CATransform3DMakeRotation(theta, 1.0, 0.0, 0.0);
                currentSamplingRotationMatrix = CATransform3DRotate(currentSamplingRotationMatrix, phi, 0.0, 1.0, 0.0);
                
                inverseMatrix = CATransform3DInvert(currentSamplingRotationMatrix);
                
                [self convert3DTransform:&inverseMatrix to3x3Matrix:inverseModelViewMatrix];
                [self convert3DTransform:&currentSamplingRotationMatrix to3x3Matrix:currentModelViewMatrix];
                
                [self renderDepthTextureForModelViewMatrix:currentModelViewMatrix translation:zeroTranslation scale:1.0];
                [self renderAmbientOcclusionTextureForModelViewMatrix:currentModelViewMatrix inverseMatrix:inverseModelViewMatrix fractionOfTotal:(0.5 / (GLfloat)AMBIENTOCCLUSIONSAMPLINGPOINTS)];
                //        [self renderAmbientOcclusionTextureForModelViewMatrix:currentModelViewMatrix inverseMatrix:inverseModelViewMatrix fractionOfTotal:(1.0 / (GLfloat)AMBIENTOCCLUSIONSAMPLINGPOINTS)];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kSLSMoleculeRenderingUpdateNotification object:[NSNumber numberWithFloat:((float)currentAOSamplingPoint * 2.0) / ((float)AMBIENTOCCLUSIONSAMPLINGPOINTS * 2.0)] ];    
                });
                
                theta = theta + M_PI / 8.0;
                phi = phi + M_PI / 8.0;
                
                currentSamplingRotationMatrix = CATransform3DMakeRotation(theta, 1.0, 0.0, 0.0);
                currentSamplingRotationMatrix = CATransform3DRotate(currentSamplingRotationMatrix, phi, 0.0, 1.0, 0.0);
                
                inverseMatrix = CATransform3DInvert(currentSamplingRotationMatrix);
                
                [self convert3DTransform:&inverseMatrix to3x3Matrix:inverseModelViewMatrix];
                [self convert3DTransform:&currentSamplingRotationMatrix to3x3Matrix:currentModelViewMatrix];
                
                [self renderDepthTextureForModelViewMatrix:currentModelViewMatrix translation:zeroTranslation scale:1.0];
                [self renderAmbientOcclusionTextureForModelViewMatrix:currentModelViewMatrix inverseMatrix:inverseModelViewMatrix fractionOfTotal:(1.5 / (GLfloat)AMBIENTOCCLUSIONSAMPLINGPOINTS)];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kSLSMoleculeRenderingUpdateNotification object:[NSNumber numberWithFloat:((float)currentAOSamplingPoint * 2.0 + 1.0) / ((float)AMBIENTOCCLUSIONSAMPLINGPOINTS * 2.0)] ];    
                });
            }    
            
//            CFTimeInterval frameDuration = CFAbsoluteTimeGetCurrent() - previousTimestamp;
            
//            NSLog(@"Ambient occlusion calculation duration: %f s", frameDuration);
        }
        
        // Reset depth texture to nearest filtering to prevent some border transparency artifacts
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, depthPassTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
        
        dispatch_semaphore_signal(frameRenderingSemaphore);
    });
}

- (void)precalculateAOLookupTextureForInverseMatrix:(GLfloat *)inverseMatrix;
{
    [self switchToAOLookupFramebuffer];

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    glBlendEquation(GL_MAX_EXT);
    
//    glBlendEquation(GL_FUNC_ADD);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Draw the spheres
    [sphereAOLookupPrecalculationProgram use];
    
    glUniformMatrix3fv(sphereAOLookupInverseModelViewMatrix, 1, 0, inverseMatrix);    
    
    static const GLfloat textureCoordinates[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
	glVertexAttribPointer(sphereAOLookupImpostorSpaceAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glEnable(GL_BLEND);
    glEnable(GL_DEPTH_TEST);
}

- (void)displayTextureToScreen:(GLuint)textureToDisplay;
{
    [self switchToDisplayFramebuffer];
    glDisable(GL_DEPTH_TEST);
    glBlendEquation(GL_MAX_EXT);
    glDepthMask(GL_FALSE);
    glEnable(GL_BLEND);

    [passthroughProgram use];
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f,  1.0f,
        1.0f,  1.0f,
    };
    
	glActiveTexture(GL_TEXTURE4);
	glBindTexture(GL_TEXTURE_2D, textureToDisplay);
	glUniform1i(passthroughTexture, 4);	
    
    glVertexAttribPointer(passthroughPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
	glVertexAttribPointer(passthroughTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glEnable(GL_DEPTH_TEST);
}

@end
