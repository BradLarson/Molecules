//
//  SLSOpenGLES11Renderer.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 4/12/2011.
//

#import "SLSOpenGLES11Renderer.h"
#import "SLSMolecule.h"

@implementation SLSOpenGLES11Renderer

#pragma mark -
#pragma mark Icosahedron tables

// These are from the OpenGL documentation at www.opengl.org
#define X .525731112119133606 
#define Z .850650808352039932

static GLfloat vdata[12][3] = 
{    
	{-X, 0.0f, Z}, 
	{0.0f, Z, X}, 
	{X, 0.0f, Z}, 
	{-Z, X, 0.0f}, 	
	{0.0f, Z, -X}, 
	{Z, X, 0.0f}, 
	{Z, -X, 0.0f}, 
	{X, 0.0f, -Z},
	{-X, 0.0f, -Z},
	{0.0f, -Z, -X},
    {0.0f, -Z, X},
	{-Z, -X, 0.0f} 
};

static GLushort tindices[20][3] = 
{ 
	{0,1,2},
	{0,3,1},
	{3,4,1},
	{1,4,5},
	{1,5,2},    
	{5,6,2},
	{5,7,6},
	{4,7,5},
	{4,8,7},
	{8,9,7},    
	{9,6,7},
	{9,10,6},
	{9,11,10},
	{11,0,10},
	{0,2,10}, 
	{10,2,6},
	{3,0,11},
	{3,11,8},
	{3,8,4},
	{9,8,11} 
};

#pragma mark -
#pragma mark Bond edge tables

static GLfloat bondEdges[4][3] = 
{ 
	{0,1,0}, {0,0,1}, {0,-1,0}, {0,0,-1} 
};

static GLushort bondIndices[8][3] = 
{
	{0,1,2}, {1,3,2}, {2,3,4}, {3,5,4}, {5,7,4}, {4,7,6}, {6,7,0}, {7,1,0}
};

#pragma mark -
#pragma mark OpenGL helper functions

void normalize(GLfloat *v) 
{    
	GLfloat d = sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]); 
	v[0] /= d; 
	v[1] /= d; 
	v[2] /= d; 
}

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithContext:(EAGLContext *)newContext;
{
	if (!(self = [super initWithContext:newContext]))
    {
		return nil;
    }
    
    return self;
}

- (void)dealloc 
{    
    [self freeVertexBuffers];
    	
}


#pragma mark -
#pragma mark OpenGL drawing support

- (BOOL)createFramebuffersForLayer:(CAEAGLLayer *)glLayer;
{	
    dispatch_async(openGLESContextQueue, ^{
        [EAGLContext setCurrentContext:context];
        
        glGenFramebuffersOES(1, &viewFramebuffer);
        glGenRenderbuffersOES(1, &viewRenderbuffer);
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
        
        // Need this to make the layer dimensions an even multiple of 32 for performance reasons
        // Also, the 4.2 Simulator will not display the 
        /*	CGRect layerBounds = glLayer.bounds;
         CGFloat newWidth = (CGFloat)((int)layerBounds.size.width / 32) * 32.0f;
         CGFloat newHeight = (CGFloat)((int)layerBounds.size.height / 32) * 32.0f;
         glLayer.bounds = CGRectMake(layerBounds.origin.x, layerBounds.origin.y, newWidth, newHeight);
         */	
        [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:glLayer];
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
        
        glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
        glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
        
        glGenRenderbuffersOES(1, &viewDepthBuffer);
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewDepthBuffer);
        glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, viewDepthBuffer);
        
        if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) 
        {
            return;
        }
        
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    });
    
	return YES;
}

- (void)destroyFramebuffers
{
    dispatch_async(openGLESContextQueue, ^{
        glDeleteFramebuffersOES(1, &viewFramebuffer);
        viewFramebuffer = 0;
        glDeleteRenderbuffersOES(1, &viewRenderbuffer);
        viewRenderbuffer = 0;
        
        if(viewDepthBuffer) 
        {
            glDeleteRenderbuffersOES(1, &viewDepthBuffer);
            viewDepthBuffer = 0;
        }
    });
}

- (void)configureLighting;
{
	const GLfloat			lightAmbient[] = {0.2, 0.2, 0.2, 1.0};
	const GLfloat			lightDiffuse[] = {1.0, 1.0, 1.0, 1.0};
	const GLfloat			matAmbient[] = {1.0, 1.0, 1.0, 1.0};
	const GLfloat			matDiffuse[] = {1.0, 1.0, 1.0, 1.0};	
	const GLfloat			lightPosition[] = {0.466, -0.466, 0, 0}; 
	const GLfloat			lightShininess = 20.0;	
	
	glEnable(GL_LIGHTING);
	glEnable(GL_LIGHT0);
	glEnable(GL_COLOR_MATERIAL);
	glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, matAmbient);
	glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, matDiffuse);
	glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, lightShininess);
	glLightfv(GL_LIGHT0, GL_AMBIENT, lightAmbient);
	glLightfv(GL_LIGHT0, GL_DIFFUSE, lightDiffuse);
	glLightfv(GL_LIGHT0, GL_POSITION, lightPosition); 		
	
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LEQUAL);
	
	glShadeModel(GL_SMOOTH);
	glDisable(GL_NORMALIZE);		
	glEnable(GL_RESCALE_NORMAL);		
	
	glEnableClientState (GL_VERTEX_ARRAY);
	glEnableClientState (GL_NORMAL_ARRAY);
	glDisableClientState (GL_COLOR_ARRAY);
	
	glDisable(GL_ALPHA_TEST);
	glDisable(GL_FOG);
	glEnable(GL_CULL_FACE);
	glCullFace(GL_FRONT);
	
	//	glEnable(GL_LINE_SMOOTH);	
}

- (void)clearScreen;
{
    dispatch_async(openGLESContextQueue, ^{
        [EAGLContext setCurrentContext:context];
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
        [context presentRenderbuffer:GL_RENDERBUFFER_OES];
    });
}

- (void)startDrawingFrame;
{
	[EAGLContext setCurrentContext:context];
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glViewport(0, 0, backingWidth, backingHeight);
    //	glScissor(0, 0, backingWidth, backingHeight);	
}

- (void)configureProjection;
{
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	
    //	glOrthof(-32768.0f, 32768.0f, -1.5f * 32768.0f, 1.5f * 32768.0f, -10.0f * 32768.0f, 4.0f * 32768.0f);
	glOrthof(-32768.0f, 32768.0f, -((float)backingHeight / (float)backingWidth) * 32768.0f, ((float)backingHeight / (float)backingWidth) * 32768.0f, -10.0f * 32768.0f, 4.0f * 32768.0f);
}

- (void)presentRenderBuffer;
{
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

#pragma mark -
#pragma mark Actual OpenGL rendering

- (void)renderFrameForMolecule:(SLSMolecule *)molecule;
{
    if (dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        return;
    }

    dispatch_async(openGLESContextQueue, ^{
        //    CFAbsoluteTime elapsedTime, startTime = CFAbsoluteTimeGetCurrent();
        
        isFrameRenderingFinished = NO;
        
        [self startDrawingFrame];
        
        if (isFirstDrawingOfMolecule)
        {
            [self configureProjection];
        }
        
        GLfloat currentModelViewMatrix[16] = {0.402560,0.094840,0.910469,0.000000, 0.913984,-0.096835,-0.394028,0.000000, 0.050796,0.990772,-0.125664,0.000000, 0.000000,0.000000,0.000000,1.000000};
        
        glMatrixMode(GL_MODELVIEW);
        
        // Reset rotation system
        if (isFirstDrawingOfMolecule)
        {
            glLoadIdentity();
            glMultMatrixf(currentModelViewMatrix);
            [self configureLighting];
            
            isFirstDrawingOfMolecule = NO;
        }
		
        // Set the new matrix that has been calculated from the Core Animation transform
        [self convert3DTransform:&currentCalculatedMatrix toMatrix:currentModelViewMatrix];
        
        glLoadMatrixf(currentModelViewMatrix);
        
        // Black background, with depth buffer enabled
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        if (molecule.isDoneRendering)
        {
            [self drawMolecule];
        }
        
        [self presentRenderBuffer];
        isFrameRenderingFinished = YES;
        
        //    elapsedTime = CFAbsoluteTimeGetCurrent() - startTime;
        //	NSLog(@"Render time: %.1f ms, Triangles per second: %.0f", elapsedTime * 1000.0, (CGFloat)totalNumberOfTriangles / elapsedTime);
        
        dispatch_semaphore_signal(frameRenderingSemaphore);
    });
}

#pragma mark -
#pragma mark Molecule 3-D geometry generation

- (void)addVertex:(GLfloat *)newVertex forAtomType:(SLSAtomType)atomType;
{
    if (atomVBOs[atomType] == nil)
    {
        atomVBOs[atomType] = [[NSMutableData alloc] init];
    }
    
	GLshort shortVertex[4];
	shortVertex[0] = (GLshort)MAX(MIN(round(newVertex[0] * 32767.0f), 32767), -32767);
	shortVertex[1] = (GLshort)MAX(MIN(round(newVertex[1] * 32767.0f), 32767), -32767);
	shortVertex[2] = (GLshort)MAX(MIN(round(newVertex[2] * 32767.0f), 32767), -32767);
	shortVertex[3] = 0;
	
    //	if ( ((newVertex[0] < -1.0f) || (newVertex[0] > 1.0f)) || ((newVertex[1] < -1.0f) || (newVertex[1] > 1.0f)) || ((newVertex[2] < -1.0f) || (newVertex[2] > 1.0f)) )
    //	{
    //		NSLog(@"Vertex outside range: %f, %f, %f", newVertex[0], newVertex[1], newVertex[2]);
    //	}
	
	[atomVBOs[atomType] appendBytes:shortVertex length:(sizeof(GLshort) * 4)];	
    
    //	[m_vertexArray appendBytes:newVertex length:(sizeof(GLfloat) * 3)];
	numberOfAtomVertices[atomType]++;
	totalNumberOfVertices++;
}

- (void)addBondVertex:(GLfloat *)newVertex;
{
    if (bondVBOs[currentBondVBO] == nil)
    {
        bondVBOs[currentBondVBO] = [[NSMutableData alloc] init];
    }
    
    GLshort shortVertex[4];
	shortVertex[0] = (GLshort)MAX(MIN(round(newVertex[0] * 32767.0f), 32767), -32767);
	shortVertex[1] = (GLshort)MAX(MIN(round(newVertex[1] * 32767.0f), 32767), -32767);
	shortVertex[2] = (GLshort)MAX(MIN(round(newVertex[2] * 32767.0f), 32767), -32767);
	shortVertex[3] = 0;
	
    //	if ( ((newVertex[0] < -1.0f) || (newVertex[0] > 1.0f)) || ((newVertex[1] < -1.0f) || (newVertex[1] > 1.0f)) || ((newVertex[2] < -1.0f) || (newVertex[2] > 1.0f)) )
    //	{
    //		NSLog(@"Vertex outside range: %f, %f, %f", newVertex[0], newVertex[1], newVertex[2]);
    //	}
	
	[bondVBOs[currentBondVBO] appendBytes:shortVertex length:(sizeof(GLshort) * 4)];	
    
    //	[m_vertexArray appendBytes:newVertex length:(sizeof(GLfloat) * 3)];
	numberOfBondVertices[currentBondVBO]++;
	totalNumberOfVertices++;
}

- (void)addNormal:(GLfloat *)newNormal forAtomType:(SLSAtomType)atomType;
{
    if (atomVBOs[atomType] == nil)
    {
        atomVBOs[atomType] = [[NSMutableData alloc] init];
    }
    
	GLshort shortNormals[4];
	shortNormals[0] = (GLshort)round(newNormal[0] * 32767.0f);
	shortNormals[1] = (GLshort)round(newNormal[1] * 32767.0f);
	shortNormals[2] = (GLshort)round(newNormal[2] * 32767.0f);
	shortNormals[3] = 0;
	
	[atomVBOs[atomType] appendBytes:shortNormals length:(sizeof(GLshort) * 4)];	
    //	[m_vertexArray appendBytes:newNormal length:(sizeof(GLfloat) * 3)];	
}

- (void)addBondNormal:(GLfloat *)newNormal;
{
    if (bondVBOs[currentBondVBO] == nil)
    {
        bondVBOs[currentBondVBO] = [[NSMutableData alloc] init];
    }
    
    GLshort shortNormals[4];
	shortNormals[0] = (GLshort)round(newNormal[0] * 32767.0f);
	shortNormals[1] = (GLshort)round(newNormal[1] * 32767.0f);
	shortNormals[2] = (GLshort)round(newNormal[2] * 32767.0f);
	shortNormals[3] = 0;
	
	[bondVBOs[currentBondVBO] appendBytes:shortNormals length:(sizeof(GLshort) * 4)];
}

- (void)addAtomToVertexBuffers:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint;
{
    float radiusScaleFactor = overallMoleculeScaleFactor * atomRadiusScaleFactor;
	GLfloat newVertex[3];
	GLfloat atomRadius = 0.4f;
    
	GLushort baseToAddToIndices = numberOfAtomVertices[atomType];
    
    SLSAtomProperties currentAtomProperties = atomProperties[atomType];
    
    atomRadius = currentAtomProperties.atomRadius;
	atomRadius *= radiusScaleFactor;
    
	for (int currentCounter = 0; currentCounter < 12; currentCounter++)
	{
		// Adjust radius and shift to match center
		newVertex[0] = (vdata[currentCounter][0] * atomRadius) + newPoint.x;
		newVertex[1] = (vdata[currentCounter][1] * atomRadius) + newPoint.y;
		newVertex[2] = (vdata[currentCounter][2] * atomRadius) + newPoint.z;
        
		// Add vertex from table
		[self addVertex:newVertex forAtomType:atomType];
        
		// Just use original icosahedron for normals
		newVertex[0] = vdata[currentCounter][0];
		newVertex[1] = vdata[currentCounter][1];
		newVertex[2] = vdata[currentCounter][2];
		
		// Add sphere normal
		[self addNormal:newVertex forAtomType:atomType];		
	}
	
	GLushort indexHolder;
	for (int currentCounter = 0; currentCounter < 20; currentCounter++)
	{
		totalNumberOfTriangles++;
		for (unsigned int internalCounter = 0; internalCounter < 3; internalCounter++)
		{
			indexHolder = baseToAddToIndices + tindices[currentCounter][internalCounter];
			[self addIndex:&indexHolder forAtomType:atomType];
		}
	}	
}

- (void)addBondToVertexBuffersWithStartPoint:(SLS3DPoint)startPoint endPoint:(SLS3DPoint)endPoint bondColor:(GLubyte *)bondColor bondType:(SLSBondType)bondType;
{
    float radiusScaleFactor = overallMoleculeScaleFactor * bondRadiusScaleFactor;

    if (currentBondVBO >= MAX_BOND_VBOS)
    {
        return;
    }
    //	SLS3DPoint startPoint, endPoint;
    //	if ( (startValue == nil) || (endValue == nil) )
    //		return;
    //	[startValue getValue:&startPoint];
    //	[endValue getValue:&endPoint];
    
	GLfloat bondRadius = radiusScaleFactor;
    
	GLfloat xDifference = endPoint.x - startPoint.x;
	GLfloat yDifference = endPoint.y - startPoint.y;
	GLfloat zDifference = endPoint.z - startPoint.z;
	GLfloat xyHypotenuse = sqrt(xDifference * xDifference + yDifference * yDifference);
	GLfloat xzHypotenuse = sqrt(xDifference * xDifference + zDifference * zDifference);
    
	GLushort baseToAddToIndices = numberOfBondVertices[currentBondVBO];
    if (baseToAddToIndices > 65500)
    {
        baseToAddToIndices = 0;
        numberOfBondVertices[currentBondVBO] = 0;
        numberOfBondIndices[currentBondVBO] = 0;
        
        currentBondVBO++;
        if (currentBondVBO >= MAX_BOND_VBOS)
        {
            return;
        }
    }

	// Do first edge vertices, colors, and normals
	for (unsigned int edgeCounter = 0; edgeCounter < 4; edgeCounter++)
	{
		SLS3DPoint calculatedNormal;
		GLfloat edgeNormal[3], edgeVertex[3];
		
		if (xyHypotenuse == 0)
		{
			calculatedNormal.x = bondEdges[edgeCounter][0];
			calculatedNormal.y = bondEdges[edgeCounter][1];
		}
		else
		{
			calculatedNormal.x = bondEdges[edgeCounter][0] * xDifference / xyHypotenuse - bondEdges[edgeCounter][1] * yDifference / xyHypotenuse;
			calculatedNormal.y = bondEdges[edgeCounter][0] * yDifference / xyHypotenuse + bondEdges[edgeCounter][1] * xDifference / xyHypotenuse;
		}
        
		if (xzHypotenuse == 0)
		{
			calculatedNormal.z = bondEdges[edgeCounter][2];
		}
		else
		{
			calculatedNormal.z = calculatedNormal.x * zDifference / xzHypotenuse + bondEdges[edgeCounter][2] * xDifference / xzHypotenuse;
			calculatedNormal.x = calculatedNormal.x * xDifference / xzHypotenuse - bondEdges[edgeCounter][2] * zDifference / xzHypotenuse;
		}
		
		edgeVertex[0] = (calculatedNormal.x * bondRadius) + startPoint.x;
		edgeVertex[1] = (calculatedNormal.y * bondRadius) + startPoint.y;
		edgeVertex[2] = (calculatedNormal.z * bondRadius) + startPoint.z;
		[self addBondVertex:edgeVertex];
        
		edgeNormal[0] = calculatedNormal.x;
		edgeNormal[1] = calculatedNormal.y;
		edgeNormal[2] = calculatedNormal.z;
		
		[self addBondNormal:edgeNormal];
		
		edgeVertex[0] = (calculatedNormal.x * bondRadius) + endPoint.x;
		edgeVertex[1] = (calculatedNormal.y * bondRadius) + endPoint.y;
		edgeVertex[2] = (calculatedNormal.z * bondRadius) + endPoint.z;
		[self addBondVertex:edgeVertex];
		[self addBondNormal:edgeNormal];
	}
    
	for (unsigned int currentCounter = 0; currentCounter < 8; currentCounter++)
	{
		totalNumberOfTriangles++;
        
		for (unsigned int internalCounter = 0; internalCounter < 3; internalCounter++)
		{
			GLushort indexHolder = baseToAddToIndices + bondIndices[currentCounter][internalCounter];
			[self addBondIndex:&indexHolder];
		}
	}
}

#pragma mark -
#pragma mark OpenGL drawing routines

- (void)bindVertexBuffersForMolecule;
{
    [super bindVertexBuffersForMolecule];
    
    isSceneReady = YES;
}

- (void)drawMolecule;
{
    // Draw all atoms first, binned based on their type
    for (unsigned int currentAtomType = 0; currentAtomType < NUM_ATOMTYPES; currentAtomType++)
    {
        if (atomIndexBufferHandle[currentAtomType] != 0)
        {
            glColor4f((GLfloat)atomProperties[currentAtomType].redComponent / 255.0f , (GLfloat)atomProperties[currentAtomType].greenComponent / 255.0f, (GLfloat)atomProperties[currentAtomType].blueComponent / 255.0f, 1.0);

            // Bind the buffers
            glBindBuffer(GL_ARRAY_BUFFER, atomVertexBufferHandles[currentAtomType]); 
            glVertexPointer(3, GL_SHORT, 16, (char *)NULL + 0); 		
            glNormalPointer(GL_SHORT, 16, (char *)NULL + 8); 
            
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, atomIndexBufferHandle[currentAtomType]);    
            
            // Do the actual drawing to the screen
            glDrawElements(GL_TRIANGLES, numberOfIndicesInBuffer[currentAtomType], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }        
    }
    
    for (unsigned int currentBondVBOIndex = 0; currentBondVBOIndex < MAX_BOND_VBOS; currentBondVBOIndex++)
    {
        // Draw bonds next
        if (bondVertexBufferHandle[currentBondVBOIndex] != 0)
        {
            GLubyte bondColor[4] = {200,200,200,255};  // Bonds are grey by default
            
            glColor4f((GLfloat)bondColor[0] / 255.0f , (GLfloat)bondColor[1] / 255.0f, (GLfloat)bondColor[2] / 255.0f, 1.0);
            
            // Bind the buffers
            glBindBuffer(GL_ARRAY_BUFFER, bondVertexBufferHandle[currentBondVBOIndex]); 
            glVertexPointer(3, GL_SHORT, 16, (char *)NULL + 0); 		
            glNormalPointer(GL_SHORT, 16, (char *)NULL + 8); 
            
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bondIndexBufferHandle[currentBondVBOIndex]);    
            
            // Do the actual drawing to the screen
            glDrawElements(GL_TRIANGLES, numberOfBondIndicesInBuffer[currentBondVBOIndex], GL_UNSIGNED_SHORT, NULL);
            
            // Unbind the buffers
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
            glBindBuffer(GL_ARRAY_BUFFER, 0); 
        }
    }
}

@end
