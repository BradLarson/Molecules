//
//  SLSOpenGLES20Renderer.h
//  Molecules
//
//  Created by Brad Larson on 4/12/2011.
//  Copyright 2011 Sunset Lake Software LLC. All rights reserved.
//

#import "SLSOpenGLESRenderer.h"

@class GLProgram;

@interface SLSOpenGLES20Renderer : SLSOpenGLESRenderer 
{
    GLProgram *sphereDepthProgram;
	GLint sphereDepthPositionAttribute, sphereDepthImpostorSpaceAttribute, sphereDepthModelViewMatrix;
    GLint sphereDepthRadius, sphereDepthOrthographicMatrix;
    
    GLProgram *cylinderDepthProgram;
    GLint cylinderDepthPositionAttribute, cylinderDepthDirectionAttribute, cylinderDepthImpostorSpaceAttribute, cylinderDepthModelViewMatrix;
    GLint cylinderDepthRadius, cylinderDepthOrthographicMatrix;
    
	GLProgram *sphereRaytracingProgram;
	GLint sphereRaytracingPositionAttribute, sphereRaytracingImpostorSpaceAttribute, sphereRaytracingModelViewMatrix;
    GLint sphereRaytracingLightPosition, sphereRaytracingRadius, sphereRaytracingColor, sphereRaytracingOrthographicMatrix;
    GLint sphereRaytracingDepthTexture;
    
	GLProgram *cylinderRaytracingProgram;
    GLint cylinderRaytracingPositionAttribute, cylinderRaytracingDirectionAttribute, cylinderRaytracingImpostorSpaceAttribute, cylinderRaytracingModelViewMatrix;
    GLint cylinderRaytracingLightPosition, cylinderRaytracingRadius, cylinderRaytracingColor, cylinderRaytracingOrthographicMatrix;
    GLint cylinderRaytracingDepthTexture;

    GLuint depthPassTexture;
	GLuint depthPassRenderbuffer, depthPassFramebuffer, depthPassDepthBuffer;

    GLfloat lightDirection[3];
    GLfloat orthographicMatrix[16];    
}

// OpenGL drawing support
- (void)initializeShaders;
- (void)loadOrthoMatrix:(GLfloat *)matrix left:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top near:(GLfloat)near far:(GLfloat)far;
- (BOOL)createFramebuffer:(GLuint *)framebufferPointer size:(CGSize)bufferSize renderBuffer:(GLuint *)renderbufferPointer depthBuffer:(GLuint *)depthbufferPointer texture:(GLuint *)backingTexturePointer layer:(CAEAGLLayer *)layer;
- (void)switchToDisplayFramebuffer;
- (void)switchToDepthPassFramebuffer;

// Molecule 3-D geometry generation
- (void)addTextureCoordinate:(GLfloat *)newTextureCoordinate forAtomType:(SLSAtomType)atomType;
- (void)addBondDirection:(GLfloat *)newDirection;
- (void)addBondTextureCoordinate:(GLfloat *)newTextureCoordinate;

// OpenGL drawing routines
- (void)renderDepthTextureForModelViewMatrix:(GLfloat *)depthModelViewMatrix;
- (void)renderRaytracedSceneForModelViewMatrix:(GLfloat *)raytracingModelViewMatrix;

@end
