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

#define MAX_BOND_VBOS 2

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
// http://www.umass.edu/microbio/rasmol/rasbonds.htm

static const SLSAtomProperties atomProperties[NUM_ATOMTYPES] = {
    {120, 120, 120, 1.55f}, // CARBON
    {255, 255, 255, 1.10f}, // HYDROGEN
    {240,  40,  40, 1.35f}, // OXYGEN
    { 48,  80, 248, 1.40f}, // NITROGEN
    {255, 255,  48, 1.81f}, // SULFUR
    {255, 128,   0, 1.88f}, // PHOSPHOROUS
    {224, 102,  51, 1.95f}, // IRON
    {  0, 255,   0, 1.50f}, // UNKNOWN
    {200, 200,  90, 1.50f}, // SILICON
};

@interface SLSOpenGLESRenderer : NSObject 
{
 	GLint backingWidth;
	GLint backingHeight;
	
    CATransform3D currentCalculatedMatrix;
	BOOL isFirstDrawingOfMolecule, isFrameRenderingFinished;

    float atomRadiusScaleFactor, bondRadiusScaleFactor, overallMoleculeScaleFactor;
    float currentModelScaleFactor;
    
	EAGLContext *context;   
    
    GLuint viewRenderbuffer, viewFramebuffer, viewDepthBuffer;	

    
	// OpenGL performance tuning statistics
	NSInteger totalNumberOfVertices, totalNumberOfTriangles;
    
    // Binned atom types
    // 16384 atoms per indexed VBO per atom type
    // 16384 bonds per indexed VBO
    NSMutableData *atomVBOs[NUM_ATOMTYPES], *atomIndexBuffers[NUM_ATOMTYPES];
    GLuint atomVertexBufferHandles[NUM_ATOMTYPES], atomIndexBufferHandle[NUM_ATOMTYPES], numberOfIndicesInBuffer[NUM_ATOMTYPES];
    GLuint bondVertexBufferHandle[MAX_BOND_VBOS], bondIndexBufferHandle[MAX_BOND_VBOS], numberOfBondIndicesInBuffer[MAX_BOND_VBOS];
    unsigned int numberOfAtomVertices[NUM_ATOMTYPES], numberOfBondVertices[MAX_BOND_VBOS], numberOfAtomIndices[NUM_ATOMTYPES], numberOfBondIndices[MAX_BOND_VBOS];

    NSMutableData *bondVBOs[MAX_BOND_VBOS], *bondIndexBuffers[MAX_BOND_VBOS];
    unsigned int currentBondVBO;
}

@property(readwrite, retain, nonatomic) EAGLContext *context;
@property (readonly) BOOL isFrameRenderingFinished;
@property (readonly) NSInteger totalNumberOfVertices, totalNumberOfTriangles;
@property (readwrite, nonatomic) float atomRadiusScaleFactor, bondRadiusScaleFactor, overallMoleculeScaleFactor;

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
- (void)destroyFramebuffers;
- (void)configureLighting;
- (void)clearScreen;
- (void)startDrawingFrame;
- (void)configureProjection;
- (void)presentRenderBuffer;

// Actual OpenGL rendering
- (void)renderFrameForMolecule:(SLSMolecule *)molecule;

// Molecule 3-D geometry generation
- (void)addVertex:(GLfloat *)newVertex forAtomType:(SLSAtomType)atomType;
- (void)addIndex:(GLushort *)newIndex forAtomType:(SLSAtomType)atomType;
- (void)addIndices:(GLushort *)newIndices size:(unsigned int)numIndices forAtomType:(SLSAtomType)atomType;
- (void)addBondVertex:(GLfloat *)newVertex;
- (void)addBondIndex:(GLushort *)newIndex;
- (void)addBondIndices:(GLushort *)newIndices size:(unsigned int)numIndices;
- (void)addAtomToVertexBuffers:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint;
- (void)addBondToVertexBuffersWithStartPoint:(SLS3DPoint)startPoint endPoint:(SLS3DPoint)endPoint bondColor:(GLubyte *)bondColor bondType:(SLSBondType)bondType;

// OpenGL drawing routines
- (void)bindVertexBuffersForMolecule;
- (void)drawMolecule;
- (void)freeVertexBuffers;
- (void)initiateMoleculeRendering;
- (void)terminateMoleculeRendering;

@end
