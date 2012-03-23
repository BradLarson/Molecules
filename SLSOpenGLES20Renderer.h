//
//  SLSOpenGLES20Renderer.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 4/12/2011.
//

#import "SLSOpenGLESRenderer.h"

#define ENABLETEXTUREDISPLAYDEBUGGING 1

@class GLProgram;

@interface SLSOpenGLES20Renderer : SLSOpenGLESRenderer 
{
    GLProgram *sphereDepthWriteProgram;
	GLint sphereDepthWritePositionAttribute, sphereDepthWriteImpostorSpaceAttribute, sphereDepthWriteModelViewMatrix;
    GLint sphereDepthWriteRadius, sphereDepthWriteOrthographicMatrix, sphereDepthWriteTranslation;

    GLProgram *sphereDepthProgram;
	GLint sphereDepthPositionAttribute, sphereDepthImpostorSpaceAttribute, sphereDepthModelViewMatrix;
    GLint sphereDepthRadius, sphereDepthOrthographicMatrix, sphereDepthTranslation, sphereDepthMapTexture;
    GLint sphereDepthPrecalculatedDepthTexture;
    
    GLProgram *cylinderDepthProgram;
    GLint cylinderDepthPositionAttribute, cylinderDepthDirectionAttribute, cylinderDepthImpostorSpaceAttribute, cylinderDepthModelViewMatrix, cylinderDepthTranslation;
    GLint cylinderDepthRadius, cylinderDepthOrthographicMatrix;
    
    GLuint depthPassTexture;
    GLuint depthPassFramebuffer, depthPassDepthBuffer;
    
    GLProgram *sphereRaytracingProgram;
	GLint sphereRaytracingPositionAttribute, sphereRaytracingImpostorSpaceAttribute, sphereRaytracingAOOffsetAttribute, sphereRaytracingModelViewMatrix;
    GLint sphereRaytracingLightPosition, sphereRaytracingRadius, sphereRaytracingColor, sphereRaytracingOrthographicMatrix, sphereRaytracingInverseModelViewMatrix, sphereRaytracingTranslation;
    GLint sphereRaytracingDepthTexture, sphereRaytracingPrecalculatedDepthTexture, sphereRaytracingAOTexture, sphereRaytracingTexturePatchWidth, sphereRaytracingPrecalculatedAOLookupTexture, sphereRaytracingDepthMapTexture;
    
	GLProgram *cylinderRaytracingProgram;
    GLint cylinderRaytracingPositionAttribute, cylinderRaytracingDirectionAttribute, cylinderRaytracingImpostorSpaceAttribute, cylinderRaytracingAOOffsetAttribute, cylinderRaytracingModelViewMatrix, cylinderRaytracingTranslation;
    GLint cylinderRaytracingLightPosition, cylinderRaytracingRadius, cylinderRaytracingColor, cylinderRaytracingOrthographicMatrix;
    GLint cylinderRaytracingDepthTexture, cylinderRaytracingInverseModelViewMatrix, cylinderRaytracingAOTexture, cylinderRaytracingTexturePatchWidth;
    
    GLProgram *sphereAmbientOcclusionProgram;
	GLint sphereAmbientOcclusionPositionAttribute, sphereAmbientOcclusionImpostorSpaceAttribute, sphereAmbientOcclusionAOOffsetAttribute, sphereAmbientOcclusionModelViewMatrix;
    GLint sphereAmbientOcclusionRadius, sphereAmbientOcclusionOrthographicMatrix, sphereAmbientOcclusionInverseModelViewMatrix, sphereAmbientOcclusionTexturePatchWidth, sphereAmbientOcclusionIntensityFactor;
    GLint sphereAmbientOcclusionDepthTexture, sphereAmbientOcclusionPrecalculatedDepthTexture;

    GLProgram *cylinderAmbientOcclusionProgram;
    GLint cylinderAmbientOcclusionPositionAttribute, cylinderAmbientOcclusionDirectionAttribute, cylinderAmbientOcclusionImpostorSpaceAttribute, cylinderAmbientOcclusionAOOffsetAttribute, cylinderAmbientOcclusionModelViewMatrix;
    GLint cylinderAmbientOcclusionRadius, cylinderAmbientOcclusionOrthographicMatrix, cylinderAmbientOcclusionInverseModelViewMatrix, cylinderAmbientOcclusionTexturePatchWidth, cylinderAmbientOcclusionIntensityFactor;
    GLint cylinderAmbientOcclusionDepthTexture;

    GLProgram *sphereAOLookupPrecalculationProgram;
	GLint sphereAOLookupImpostorSpaceAttribute, sphereAOLookupInverseModelViewMatrix;
    GLint sphereAOLookupPrecalculatedDepthTexture;

    GLuint sphereAOLookupTexture;
    GLuint sphereAOLookupFramebuffer;

#ifdef ENABLETEXTUREDISPLAYDEBUGGING
    GLProgram *passthroughProgram;
    GLint passthroughPositionAttribute, passthroughTextureCoordinateAttribute;
    GLint passthroughTexture;
#endif
    
    GLuint ambientOcclusionTexture;
    GLuint ambientOcclusionFramebuffer;
    
    GLuint sphereDepthMappingTexture;

    GLfloat previousAmbientOcclusionOffset[2];
    GLfloat lightDirection[3];
    GLfloat orthographicMatrix[9];
    GLfloat accumulatedModelTranslation[3];
    
    CGSize currentViewportSize;
    
    unsigned int widthOfAtomAOTexturePatch;
    GLfloat normalizedAOTexturePatchWidth;
    
    unsigned int ambientOcclusionTextureWidth, ambientOcclusionLookupTextureWidth, sphereDepthTextureWidth;
    
    BOOL shouldDrawBonds;
}

// OpenGL drawing support
- (void)initializeDepthShaders;
- (void)initializeAmbientOcclusionShaders;
- (void)initializeRaytracingShaders;
- (void)loadOrthoMatrix:(GLfloat *)matrix left:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top near:(GLfloat)near far:(GLfloat)far;
- (BOOL)createFramebuffer:(GLuint *)framebufferPointer size:(CGSize)bufferSize renderBuffer:(GLuint *)renderbufferPointer depthBuffer:(GLuint *)depthbufferPointer texture:(GLuint *)backingTexturePointer layer:(CAEAGLLayer *)layer;
- (void)switchToDisplayFramebuffer;
- (void)switchToDepthPassFramebuffer;
- (void)switchToAmbientOcclusionFramebuffer;
- (void)switchToAOLookupFramebuffer;
- (void)generateSphereDepthMapTexture;

// Molecule 3-D geometry generation
- (void)addTextureCoordinate:(GLfloat *)newTextureCoordinate forAtomType:(SLSAtomType)atomType;
- (void)addAmbientOcclusionTextureOffset:(GLfloat *)ambientOcclusionOffset forAtomType:(SLSAtomType)atomType;
- (void)addBondDirection:(GLfloat *)newDirection;
- (void)addBondTextureCoordinate:(GLfloat *)newTextureCoordinate;
- (void)addBondAmbientOcclusionTextureOffset:(GLfloat *)ambientOcclusionOffset;

// OpenGL drawing routines
- (void)renderDepthTextureForModelViewMatrix:(GLfloat *)depthModelViewMatrix translation:(GLfloat *)modelTranslation scale:(GLfloat)scaleFactor;
- (void)writeDepthValuesForOpaqueAreasForModelViewMatrix:(GLfloat *)depthModelViewMatrix translation:(GLfloat *)modelTranslation scale:(GLfloat)scaleFactor;
- (void)renderRaytracedSceneForModelViewMatrix:(GLfloat *)raytracingModelViewMatrix inverseMatrix:(GLfloat *)inverseMatrix translation:(GLfloat *)modelTranslation scale:(GLfloat)scaleFactor;
- (void)renderAmbientOcclusionTextureForModelViewMatrix:(GLfloat *)ambientOcclusionModelViewMatrix inverseMatrix:(GLfloat *)inverseMatrix fractionOfTotal:(GLfloat)fractionOfTotal;
- (void)prepareAmbientOcclusionMap;
- (void)precalculateAOLookupTextureForInverseMatrix:(GLfloat *)inverseMatrix;
- (void)displayTextureToScreen:(GLuint)textureToDisplay;

@end
