//
//  SLSOpenGLESRenderer.h
//  Molecules
//
//  Created by Brad Larson on 4/12/2011.
//  Copyright 2011 Sunset Lake Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#import "SLSMolecule.h"

// OpenGL helper functions
void normalize(GLfloat *v);

typedef typedef struct { 
    GLubyte redComponent;
    GLubyte greenComponent;
    GLubyte blueComponent;
    GLfloat atomRadius; 
} SLSAtomProperties;

//typedef enum { CARBON, HYDROGEN, OXYGEN, NITROGEN, SULFUR, PHOSPHOROUS, IRON, UNKNOWN, SILICON, NUM_ATOMTYPES } SLSAtomType;
// van der Waals radius used here


static const SLSAtomProperties atomProperties[NUM_ATOMTYPES] = {
    {144, 144, 144, 1.70f}, // CARBON
    {255, 255, 255, 1.09f}, // HYDROGEN
    {240,   0,   0, 1.52f}, // OXYGEN
    { 48,  80, 248, 1.55f}, // NITROGEN
    {255, 255,  48, 1.80f}, // SULFUR
    {255, 128,   0, 1.80f}, // PHOSPHOROUS
    {224, 102,  51, 2.00f}, // IRON
    {255, 255, 255, 1.09f}, // UNKNOWN
    {  0, 255,   0, 1.70f}, // SILICON
};

@interface SLSOpenGLESRenderer : NSObject 
{
 	GLint backingWidth;
	GLint backingHeight;
	
    CATransform3D currentCalculatedMatrix;
	BOOL isFirstDrawingOfMolecule, isFrameRenderingFinished;

    float atomRadiusScaleFactor, bondRadiusScaleFactor;
    
	EAGLContext *context;   
    
    GLuint viewRenderbuffer, viewFramebuffer, viewDepthBuffer;	

	// OpenGL performance tuning statistics
	NSInteger totalNumberOfVertices, totalNumberOfTriangles;
    
    // Binned atom types
    // 16384 atoms per indexed VBO per atom type
    // 16384 bonds per indexed VBO
    NSMutableDictionary *atomVBOs, *atomIndices;
    
    NSMutableArray *bondVBOs, *bondIndexObjects, *bondDirections;
    
}

@property(readwrite, retain, nonatomic) EAGLContext *context;
@property (readonly) BOOL isFrameRenderingFinished;
@property (readonly) NSInteger totalNumberOfVertices, totalNumberOfTriangles;

// Initialization and teardown
- (id)initWithContext:(EAGLContext *)newContext;

// OpenGL matrix helper methods
- (void)convertMatrix:(GLfloat *)matrix to3DTransform:(CATransform3D *)transform3D;
- (void)convert3DTransform:(CATransform3D *)transform3D toMatrix:(GLfloat *)matrix;
- (void)print3DTransform:(CATransform3D *)transform3D;
- (void)printMatrix:(GLfloat *)fixedPointMatrix;

// Model manipulation
- (void)rotateModelFromScreenDisplacementInX:(float)xRotation inY:(float)yRotation;
- (void)scaleModelByFactor:(float)scaleFactor;
- (void)translateModelByScreenDisplacementInX:(float)xTranslation inY:(float)yTranslation;
- (void)resetModelViewMatrix;

// OpenGL drawing support
- (BOOL)createFramebuffersForLayer:(CAEAGLLayer *)glLayer;
- (void)destroyFramebuffer;
- (void)configureLighting;
- (void)clearScreen;
- (void)startDrawingFrame;
- (void)configureProjection;
- (void)presentRenderBuffer;

// Actual OpenGL rendering
- (void)renderFrameForMolecule:(SLSMolecule *)molecule;

// Molecule 3-D geometry generation
- (void)addNormal:(GLfloat *)newNormal;
- (void)addVertex:(GLfloat *)newVertex;
- (void)addIndex:(GLushort *)newIndex;
- (void)addAtomToVertexBuffers:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint radiusScaleFactor:(float)radiusScaleFactor;
- (void)addBondToVertexBuffersWithStartPoint:(SLS3DPoint)startPoint endPoint:(SLS3DPoint)endPoint bondColor:(GLubyte *)bondColor bondType:(SLSBondType)bondType radiusScaleFactor:(float)radiusScaleFactor;

// OpenGL drawing routines
- (void)addVertexBuffer;
- (void)bindVertexBuffersForMolecule;
- (void)drawMolecule;
- (void)freeVertexBuffers;
- (void)initiateMoleculeRendering;
- (void)terminateMoleculeRendering;

@end
