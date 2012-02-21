//
//  SLSOpenGLESRenderer.m
//  Molecules
//
//  Created by Brad Larson on 4/12/2011.
//  Copyright 2011 Sunset Lake Software LLC. All rights reserved.
//

#import "SLSOpenGLESRenderer.h"

NSString *const kSLSMoleculeShadowCalculationStartedNotification = @"MoleculeShadowCalculationStarted";
NSString *const kSLSMoleculeShadowCalculationUpdateNotification = @"MoleculeShadowCalculationUpdate";
NSString *const kSLSMoleculeShadowCalculationEndedNotification = @"MoleculeShadowCalculationEnded";

@implementation SLSOpenGLESRenderer

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithContext:(EAGLContext *)newContext;
{
    if (!(self = [super init]))
    {
        return nil;
    }

    self.context = newContext;
    
    isSceneReady = NO;
    
    // Set up the initial model view matrix for the rendering
    isFirstDrawingOfMolecule = YES;
    isFrameRenderingFinished = YES;
    totalNumberOfVertices = 0;
	totalNumberOfTriangles = 0;
    currentModelScaleFactor = 1.0;

    GLfloat currentModelViewMatrix[16]  = {0.402560,0.094840,0.910469,0.000000, 0.913984,-0.096835,-0.394028,0.000000, 0.050796,0.990772,-0.125664,0.000000, 0.000000,0.000000,0.000000,1.000000};
    
    //		GLfloat currentModelViewMatrix[16]  = {1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0};
    
    [self convertMatrix:currentModelViewMatrix to3DTransform:&currentCalculatedMatrix];

    openGLESContextQueue = dispatch_queue_create("com.sunsetlakesoftware.openGLESContextQueue", NULL);;
    frameRenderingSemaphore = dispatch_semaphore_create(1);

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
	
    
    dispatch_release(openGLESContextQueue);
    dispatch_release(frameRenderingSemaphore);
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

- (void)convert3DTransform:(CATransform3D *)transform3D to3x3Matrix:(GLfloat *)matrix;
{
	matrix[0] = (GLfloat)transform3D->m11;
	matrix[1] = (GLfloat)transform3D->m12;
	matrix[2] = (GLfloat)transform3D->m13;
	matrix[3] = (GLfloat)transform3D->m21;
	matrix[4] = (GLfloat)transform3D->m22;
	matrix[5] = (GLfloat)transform3D->m23;
	matrix[6] = (GLfloat)transform3D->m31;
	matrix[7] = (GLfloat)transform3D->m32;
	matrix[8] = (GLfloat)transform3D->m33;
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

- (void)apply3DTransform:(CATransform3D *)transform3D toPoint:(GLfloat *)sourcePoint result:(GLfloat *)resultingPoint;
{
//        | A B C D |
//    M = | E F G H |
//        | I J K L |
//        | M N O P |
    
//    A.x1+B.y1+C.z1+D
//    E.x1+F.y1+G.z1+H
//    I.x1+J.y1+K.z1+L
//    M.x1+N.y1+O.z1+P

    resultingPoint[0] = sourcePoint[0] * transform3D->m11 + sourcePoint[1] * transform3D->m12 + sourcePoint[2] * transform3D->m13 + transform3D->m14;
    resultingPoint[1] = sourcePoint[0] * transform3D->m21 + sourcePoint[1] * transform3D->m22 + sourcePoint[2] * transform3D->m23 + transform3D->m24;
    resultingPoint[2] = sourcePoint[0] * transform3D->m31 + sourcePoint[1] * transform3D->m32 + sourcePoint[2] * transform3D->m33 + transform3D->m34;
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
        currentModelScaleFactor = currentModelScaleFactor * scaleFactor;
    }
}

- (void)translateModelByScreenDisplacementInX:(float)xTranslation inY:(float)yTranslation;
{
    float scalingForMovement;
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        scalingForMovement = 85.0f;
    }
    else
    {
        scalingForMovement = 200.0f;
    }
    

    // Translate the model by the accumulated amount
	float currentScaleFactor = sqrt(pow(currentCalculatedMatrix.m11, 2.0f) + pow(currentCalculatedMatrix.m12, 2.0f) + pow(currentCalculatedMatrix.m13, 2.0f));	

	xTranslation = xTranslation * scalingForMovement / (currentScaleFactor * currentScaleFactor);
	yTranslation = yTranslation * scalingForMovement / (currentScaleFactor * currentScaleFactor);

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
    currentModelScaleFactor = 1.0;
    
    isFirstDrawingOfMolecule = YES;
}

#pragma mark -
#pragma mark OpenGL drawing support

- (BOOL)createFramebuffersForLayer:(CAEAGLLayer *)glLayer;
{
    return YES;
}

- (void)destroyFramebuffers;
{
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

- (void)suspendRenderingDuringRotation;
{
    
}

- (void)resumeRenderingDuringRotation;
{
    
}

#pragma mark -
#pragma mark Actual OpenGL rendering

- (void)renderFrameForMolecule:(SLSMolecule *)molecule;
{
    NSAssert(NO, @"Method not overridden");
}

#pragma mark -
#pragma mark Molecule 3-D geometry generation

- (void)configureBasedOnNumberOfAtoms:(unsigned int)numberOfAtoms numberOfBonds:(unsigned int)numberOfBonds;
{
    
}

- (void)addVertex:(GLfloat *)newVertex forAtomType:(SLSAtomType)atomType;
{
}

- (void)addIndex:(GLushort *)newIndex forAtomType:(SLSAtomType)atomType;
{
    if (atomIndexBuffers[atomType] == nil)
    {
        atomIndexBuffers[atomType] = [[NSMutableData alloc] init];
    }
    
	[atomIndexBuffers[atomType] appendBytes:newIndex length:sizeof(GLushort)];
	numberOfAtomIndices[atomType]++;
}

- (void)addIndices:(GLushort *)newIndices size:(unsigned int)numIndices forAtomType:(SLSAtomType)atomType;
{
    if (atomIndexBuffers[atomType] == nil)
    {
        atomIndexBuffers[atomType] = [[NSMutableData alloc] init];
    }

    [atomIndexBuffers[atomType] appendBytes:newIndices length:(sizeof(GLushort) * numIndices)];
	numberOfAtomIndices[atomType] += numIndices;
}

- (void)addBondVertex:(GLfloat *)newVertex;
{
}

- (void)addBondIndex:(GLushort *)newIndex;
{
    if (bondIndexBuffers[currentBondVBO] == nil)
    {
        bondIndexBuffers[currentBondVBO] = [[NSMutableData alloc] init];
    }
    
	[bondIndexBuffers[currentBondVBO] appendBytes:newIndex length:sizeof(GLushort)];
	numberOfBondIndices[currentBondVBO]++;
}

- (void)addBondIndices:(GLushort *)newIndices size:(unsigned int)numIndices;
{
    if (bondIndexBuffers[currentBondVBO] == nil)
    {
        bondIndexBuffers[currentBondVBO] = [[NSMutableData alloc] init];
    }
    
	[bondIndexBuffers[currentBondVBO] appendBytes:newIndices length:(sizeof(GLushort) * numIndices)];
	numberOfBondIndices[currentBondVBO] += numIndices;
}

- (void)addAtomToVertexBuffers:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)addBondToVertexBuffersWithStartPoint:(SLS3DPoint)startPoint endPoint:(SLS3DPoint)endPoint bondColor:(GLubyte *)bondColor bondType:(SLSBondType)bondType;
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
    dispatch_async(openGLESContextQueue, ^{
        [EAGLContext setCurrentContext:context];

        [self resetModelViewMatrix];

        isRenderingCancelled = NO;
        
        for (unsigned int currentAtomIndexBufferIndex = 0; currentAtomIndexBufferIndex < NUM_ATOMTYPES; currentAtomIndexBufferIndex++)
        {            
            if (atomIndexBuffers[currentAtomIndexBufferIndex] != nil)
            {
                glGenBuffers(1, &atomIndexBufferHandle[currentAtomIndexBufferIndex]);
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, atomIndexBufferHandle[currentAtomIndexBufferIndex]);   
                glBufferData(GL_ELEMENT_ARRAY_BUFFER, [atomIndexBuffers[currentAtomIndexBufferIndex] length], (GLushort *)[atomIndexBuffers[currentAtomIndexBufferIndex] bytes], GL_STATIC_DRAW);    
                
                numberOfIndicesInBuffer[currentAtomIndexBufferIndex] = ([atomIndexBuffers[currentAtomIndexBufferIndex] length] / sizeof(GLushort));
                
                // Now that the data are in the OpenGL buffer, can release the NSData
                atomIndexBuffers[currentAtomIndexBufferIndex] = nil;
            }
            else
            {
                atomIndexBufferHandle[currentAtomIndexBufferIndex] = 0;
            }
        }
        
        for (unsigned int currentAtomVBOIndex = 0; currentAtomVBOIndex < NUM_ATOMTYPES; currentAtomVBOIndex++)
        {
            if (atomVBOs[currentAtomVBOIndex] != nil)
            {
                glGenBuffers(1, &atomVertexBufferHandles[currentAtomVBOIndex]);
                glBindBuffer(GL_ARRAY_BUFFER, atomVertexBufferHandles[currentAtomVBOIndex]);
                glBufferData(GL_ARRAY_BUFFER, [atomVBOs[currentAtomVBOIndex] length], (void *)[atomVBOs[currentAtomVBOIndex] bytes], GL_STATIC_DRAW); 
                
                atomVBOs[currentAtomVBOIndex] = nil;
            }
            else
            {
                atomVertexBufferHandles[currentAtomVBOIndex] = 0;
            }
        }
        
        for (unsigned int currentBondVBOIndex = 0; currentBondVBOIndex < MAX_BOND_VBOS; currentBondVBOIndex++)
        {
            if (bondVBOs[currentBondVBOIndex] != nil)
            {
                glGenBuffers(1, &bondIndexBufferHandle[currentBondVBOIndex]);
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bondIndexBufferHandle[currentBondVBOIndex]);   
                glBufferData(GL_ELEMENT_ARRAY_BUFFER, [bondIndexBuffers[currentBondVBOIndex] length], (GLushort *)[bondIndexBuffers[currentBondVBOIndex] bytes], GL_STATIC_DRAW);    
                
                numberOfBondIndicesInBuffer[currentBondVBOIndex] = ([bondIndexBuffers[currentBondVBOIndex] length] / sizeof(GLushort));
                
                bondIndexBuffers[currentBondVBOIndex] = nil;
                
                glGenBuffers(1, &bondVertexBufferHandle[currentBondVBOIndex]);
                glBindBuffer(GL_ARRAY_BUFFER, bondVertexBufferHandle[currentBondVBOIndex]);
                glBufferData(GL_ARRAY_BUFFER, [bondVBOs[currentBondVBOIndex] length], (void *)[bondVBOs[currentBondVBOIndex] bytes], GL_STATIC_DRAW); 
                
                bondVBOs[currentBondVBOIndex] = nil;
            }
        }    
    });    
}

- (void)drawMolecule;
{
    NSAssert(NO, @"Method not overridden");
}

- (void)freeVertexBuffers;
{    
    dispatch_async(openGLESContextQueue, ^{
        [EAGLContext setCurrentContext:context];
        
        isSceneReady = NO;
        
        for (unsigned int currentAtomType = 0; currentAtomType < NUM_ATOMTYPES; currentAtomType++)
        {
            if (atomIndexBufferHandle[currentAtomType] != 0)
            {
                glDeleteBuffers(1, &atomIndexBufferHandle[currentAtomType]);
                glDeleteBuffers(1, &atomVertexBufferHandles[currentAtomType]);
                
                atomIndexBufferHandle[currentAtomType] = 0;
                atomVertexBufferHandles[currentAtomType] = 0;
            }
        }
        if (bondVertexBufferHandle != 0)
        {
            for (unsigned int currentBondVBOIndex = 0; currentBondVBOIndex < MAX_BOND_VBOS; currentBondVBOIndex++)
            {
                if (bondIndexBufferHandle[currentBondVBOIndex] != 0)
                {
                    glDeleteBuffers(1, &bondVertexBufferHandle[currentBondVBOIndex]);
                    glDeleteBuffers(1, &bondIndexBufferHandle[currentBondVBOIndex]);   
                }
                
                bondVertexBufferHandle[currentBondVBOIndex] = 0;
                bondIndexBufferHandle[currentBondVBOIndex] = 0;
            }
        }
        
        totalNumberOfTriangles = 0;
        totalNumberOfVertices = 0;
    });
}

- (void)initiateMoleculeRendering;
{
    for (unsigned int currentAtomTypeIndex = 0; currentAtomTypeIndex < NUM_ATOMTYPES; currentAtomTypeIndex++)
    {
        numberOfAtomVertices[currentAtomTypeIndex] = 0;
        numberOfAtomIndices[currentAtomTypeIndex] = 0;
    }
    
    for (unsigned int currentBondVBOIndex = 0; currentBondVBOIndex < MAX_BOND_VBOS; currentBondVBOIndex++)
    {
        numberOfBondVertices[currentBondVBOIndex] = 0;
        numberOfBondIndices[currentBondVBOIndex] = 0;
    }
    
    currentBondVBO = 0;
    currentAtomVBO = 0;
}

- (void)terminateMoleculeRendering;
{
    // Release all the NSData arrays that were partially generated
    for (unsigned int currentVBOIndex = 0; currentVBOIndex < NUM_ATOMTYPES; currentVBOIndex++)
    {
        if (atomVBOs[currentVBOIndex] != nil)
        {
            atomVBOs[currentVBOIndex] = nil;
        }
    }
    
    for (unsigned int currentIndexBufferIndex = 0; currentIndexBufferIndex < NUM_ATOMTYPES; currentIndexBufferIndex++)
    {
        if (atomIndexBuffers[currentIndexBufferIndex] != nil)
        {
            atomIndexBuffers[currentIndexBufferIndex] = nil;
        }
    }
    
    for (unsigned int currentBondVBOIndex = 0; currentBondVBOIndex < MAX_BOND_VBOS; currentBondVBOIndex++)
    {
        bondVBOs[currentBondVBOIndex] = nil;
        
        bondIndexBuffers[currentBondVBOIndex] = nil;
    }    
}

- (void)cancelMoleculeRendering;
{
    isRenderingCancelled = YES;    
}

- (void)waitForLastFrameToFinishRendering;
{
    dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);
    dispatch_semaphore_signal(frameRenderingSemaphore);
}

#pragma mark -
#pragma mark Accessors

@synthesize context;
@synthesize isFrameRenderingFinished, isSceneReady;
@synthesize totalNumberOfVertices, totalNumberOfTriangles;
@synthesize atomRadiusScaleFactor, bondRadiusScaleFactor, overallMoleculeScaleFactor;
@synthesize openGLESContextQueue;

@end
