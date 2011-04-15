//
//  SLSOpenGLESRenderer.m
//  Molecules
//
//  Created by Brad Larson on 4/12/2011.
//  Copyright 2011 Sunset Lake Software LLC. All rights reserved.
//

#import "SLSOpenGLESRenderer.h"

@implementation SLSOpenGLESRenderer

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithContext:(EAGLContext *)newContext;
{
	if (![super init])
    {
		return nil;
    }

    self.context = newContext;
    
    // Set up the initial model view matrix for the rendering
    isFirstDrawingOfMolecule = YES;
    isFrameRenderingFinished = YES;
    totalNumberOfVertices = 0;
	totalNumberOfTriangles = 0;

    GLfloat currentModelViewMatrix[16]  = {0.402560,0.094840,0.910469,0.000000, 0.913984,-0.096835,-0.394028,0.000000, 0.050796,0.990772,-0.125664,0.000000, 0.000000,0.000000,0.000000,1.000000};
    
    //		GLfloat currentModelViewMatrix[16]  = {1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0};
    
    [self convertMatrix:currentModelViewMatrix to3DTransform:&currentCalculatedMatrix];

//    [self clearScreen];		

    return self;
}

- (void)dealloc 
{
    //	// Read the current modelview matrix from OpenGL and save it in the user's preferences for recovery on next startup
    //	// TODO: save index, vertex, and normal buffers for quick reload later
    //	float currentModelViewMatrix[16];
    //	glMatrixMode(GL_MODELVIEW);
    //	glGetFloatv(GL_MODELVIEW_MATRIX, currentModelViewMatrix);	
    //	NSData *matrixData = [NSData dataWithBytes:currentModelViewMatrix length:(16 * sizeof(float))];	
    //	[[NSUserDefaults standardUserDefaults] setObject:matrixData forKey:@"matrixData"];	
    //	
	if ([EAGLContext currentContext] == context) 
	{
		[EAGLContext setCurrentContext:nil];
	}
	
	[context release];	
    
	[super dealloc];
}

#pragma mark -
#pragma mark OpenGL matrix helper methods

- (void)convertMatrix:(GLfloat *)matrix to3DTransform:(CATransform3D *)transform3D;
{
	transform3D->m11 = (CGFloat)matrix[0];
	transform3D->m12 = (CGFloat)matrix[1];
	transform3D->m13 = (CGFloat)matrix[2];
	transform3D->m14 = (CGFloat)matrix[3];
	transform3D->m21 = (CGFloat)matrix[4];
	transform3D->m22 = (CGFloat)matrix[5];
	transform3D->m23 = (CGFloat)matrix[6];
	transform3D->m24 = (CGFloat)matrix[7];
	transform3D->m31 = (CGFloat)matrix[8];
	transform3D->m32 = (CGFloat)matrix[9];
	transform3D->m33 = (CGFloat)matrix[10];
	transform3D->m34 = (CGFloat)matrix[11];
	transform3D->m41 = (CGFloat)matrix[12];
	transform3D->m42 = (CGFloat)matrix[13];
	transform3D->m43 = (CGFloat)matrix[14];
	transform3D->m44 = (CGFloat)matrix[15];
}

- (void)convert3DTransform:(CATransform3D *)transform3D toMatrix:(GLfloat *)matrix;
{
	//	struct CATransform3D
	//	{
	//		CGFloat m11, m12, m13, m14;
	//		CGFloat m21, m22, m23, m24;
	//		CGFloat m31, m32, m33, m34;
	//		CGFloat m41, m42, m43, m44;
	//	};
	
	matrix[0] = (GLfloat)transform3D->m11;
	matrix[1] = (GLfloat)transform3D->m12;
	matrix[2] = (GLfloat)transform3D->m13;
	matrix[3] = (GLfloat)transform3D->m14;
	matrix[4] = (GLfloat)transform3D->m21;
	matrix[5] = (GLfloat)transform3D->m22;
	matrix[6] = (GLfloat)transform3D->m23;
	matrix[7] = (GLfloat)transform3D->m24;
	matrix[8] = (GLfloat)transform3D->m31;
	matrix[9] = (GLfloat)transform3D->m32;
	matrix[10] = (GLfloat)transform3D->m33;
	matrix[11] = (GLfloat)transform3D->m34;
	matrix[12] = (GLfloat)transform3D->m41;
	matrix[13] = (GLfloat)transform3D->m42;
	matrix[14] = (GLfloat)transform3D->m43;
	matrix[15] = (GLfloat)transform3D->m44;
}

- (void)print3DTransform:(CATransform3D *)transform3D;
{
	NSLog(@"___________________________");
	NSLog(@"|%f,%f,%f,%f|", transform3D->m11, transform3D->m12, transform3D->m13, transform3D->m14);
	NSLog(@"|%f,%f,%f,%f|", transform3D->m21, transform3D->m22, transform3D->m23, transform3D->m24);
	NSLog(@"|%f,%f,%f,%f|", transform3D->m31, transform3D->m32, transform3D->m33, transform3D->m34);
	NSLog(@"|%f,%f,%f,%f|", transform3D->m41, transform3D->m42, transform3D->m43, transform3D->m44);
	NSLog(@"___________________________");			
}

- (void)printMatrix:(GLfloat *)matrix;
{
	NSLog(@"___________________________");
	NSLog(@"|%f,%f,%f,%f|", matrix[0], matrix[1], matrix[2], matrix[3]);
	NSLog(@"|%f,%f,%f,%f|", matrix[4], matrix[5], matrix[6], matrix[7]);
	NSLog(@"|%f,%f,%f,%f|", matrix[8], matrix[9], matrix[10], matrix[11]);
	NSLog(@"|%f,%f,%f,%f|", matrix[12], matrix[13], matrix[14], matrix[15]);
	NSLog(@"___________________________");			
}

#pragma mark -
#pragma mark Model manipulation

- (void)rotateModelFromScreenDisplacementInX:(float)xRotation inY:(float)yRotation;
{
	// Perform incremental rotation based on current angles in X and Y	
	GLfloat totalRotation = sqrt(xRotation*xRotation + yRotation*yRotation);
	
	CATransform3D temporaryMatrix = CATransform3DRotate(currentCalculatedMatrix, totalRotation * M_PI / 180.0, 
														((xRotation/totalRotation) * currentCalculatedMatrix.m12 + (yRotation/totalRotation) * currentCalculatedMatrix.m11),
														((xRotation/totalRotation) * currentCalculatedMatrix.m22 + (yRotation/totalRotation) * currentCalculatedMatrix.m21),
														((xRotation/totalRotation) * currentCalculatedMatrix.m32 + (yRotation/totalRotation) * currentCalculatedMatrix.m31));

	if ((temporaryMatrix.m11 >= -100.0) && (temporaryMatrix.m11 <= 100.0))
    {
		currentCalculatedMatrix = temporaryMatrix;
    }    
}

- (void)scaleModelByFactor:(float)scaleFactor;
{
    // Scale the view to fit current multitouch scaling
	CATransform3D temporaryMatrix = CATransform3DScale(currentCalculatedMatrix, scaleFactor, scaleFactor, scaleFactor);
	
	if ((temporaryMatrix.m11 >= -100.0) && (temporaryMatrix.m11 <= 100.0))
    {
		currentCalculatedMatrix = temporaryMatrix;
    }
}

- (void)translateModelByScreenDisplacementInX:(float)xTranslation inY:(float)yTranslation;
{
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
}

- (void)resetModelViewMatrix;
{
 	GLfloat currentModelViewMatrix[16]  = {0.402560,0.094840,0.910469,0.000000, 0.913984,-0.096835,-0.394028,0.000000, 0.050796,0.990772,-0.125664,0.000000, 0.000000,0.000000,0.000000,1.000000};
	[self convertMatrix:currentModelViewMatrix to3DTransform:&currentCalculatedMatrix];   
    
    isFirstDrawingOfMolecule = YES;
}

#pragma mark -
#pragma mark OpenGL drawing support

- (BOOL)createFramebuffersForLayer:(CAEAGLLayer *)glLayer;
{
    return YES;
}

- (void)destroyFramebuffer;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)configureLighting;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)clearScreen;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)startDrawingFrame;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)configureProjection;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)presentRenderBuffer;
{
    NSAssert(NO, @"Method not overridden");
}

#pragma mark -
#pragma mark Actual OpenGL rendering

- (void)renderFrameForMolecule:(SLSMolecule *)molecule;
{
    NSAssert(NO, @"Method not overridden");
}

#pragma mark -
#pragma mark Molecule 3-D geometry generation

- (void)addVertex:(GLfloat *)newVertex forAtomType:(SLSAtomType)atomType;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)addIndex:(GLushort *)newIndex forAtomType:(SLSAtomType)atomType;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)addBondVertex:(GLfloat *)newVertex;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)addBondIndex:(GLushort *)newIndex;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)addAtomToVertexBuffers:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint radiusScaleFactor:(float)radiusScaleFactor;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)addBondToVertexBuffersWithStartPoint:(SLS3DPoint)startPoint endPoint:(SLS3DPoint)endPoint bondColor:(GLubyte *)bondColor bondType:(SLSBondType)bondType radiusScaleFactor:(float)radiusScaleFactor;
{
    NSAssert(NO, @"Method not overridden");
}

#pragma mark -
#pragma mark OpenGL drawing routines

- (void)addVertexBuffer;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)bindVertexBuffersForMolecule;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)drawMolecule;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)freeVertexBuffers;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)initiateMoleculeRendering;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)terminateMoleculeRendering;
{
    NSAssert(NO, @"Method not overridden");
}

#pragma mark -
#pragma mark Accessors

@synthesize context;
@synthesize isFrameRenderingFinished;
@synthesize totalNumberOfVertices, totalNumberOfTriangles;

@end
