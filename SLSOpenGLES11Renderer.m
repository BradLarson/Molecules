//
//  SLSOpenGLES11Renderer.m
//  Molecules
//
//  Created by Brad Larson on 4/12/2011.
//  Copyright 2011 Sunset Lake Software LLC. All rights reserved.
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
	if (![super initWithContext:newContext])
    {
		return nil;
    }
    
    m_numVertices = 0;
	m_numIndices = 0;
	m_numberOfVertexBuffers = 0;
	m_vertexArray = nil;
	m_numberOfIndicesForBuffers = NULL;

    m_vertexBufferHandle = NULL;
	m_indexBufferHandle = NULL;
    
    return self;
}

- (void)dealloc 
{
 	// All buffers are deallocated after they are bound to their OpenGL counterparts,
	// but we still need to delete the OpenGL buffers themselves when done
	if (m_numberOfIndicesForBuffers != NULL)
	{
		free(m_numberOfIndicesForBuffers);
        //		m_numberOfVertexBuffers = NULL;
	}
    
	if (m_vertexBufferHandle != NULL)
    {
		[self freeVertexBuffers];
    }
    
	[m_vertexArrays release];
	[m_indexArrays release];
	[m_vertexArray release];
	[m_indexArray release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark OpenGL drawing support

- (BOOL)createFramebuffersForLayer:(CAEAGLLayer *)glLayer;
{	
    [EAGLContext setCurrentContext:context];
    
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    
	// Need this to make the layer dimensions an even multiple of 32 for performance reasons
	// Also, the 4.2 Simulator will not display the 
	CGRect layerBounds = glLayer.bounds;
	CGFloat newWidth = (CGFloat)((int)layerBounds.size.width / 32) * 32.0f;
	CGFloat newHeight = (CGFloat)((int)layerBounds.size.height / 32) * 32.0f;
	glLayer.bounds = CGRectMake(layerBounds.origin.x, layerBounds.origin.y, newWidth, newHeight);
	
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
		return NO;
	}
	
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    
	return YES;
}

- (void)destroyFramebuffer 
{
	glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
	
	if(viewDepthBuffer) 
    {
		glDeleteRenderbuffersOES(1, &viewDepthBuffer);
		viewDepthBuffer = 0;
	}
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
	[EAGLContext setCurrentContext:context];
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
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

}

#pragma mark -
#pragma mark Molecule 3-D geometry generation

- (void)addNormal:(GLfloat *)newNormal;
{
	GLshort shortNormals[4];
	shortNormals[0] = (GLshort)round(newNormal[0] * 32767.0f);
	
	
	shortNormals[1] = (GLshort)round(newNormal[1] * 32767.0f);
	shortNormals[2] = (GLshort)round(newNormal[2] * 32767.0f);
	shortNormals[3] = 0;
	
	[m_vertexArray appendBytes:shortNormals length:(sizeof(GLshort) * 4)];	
    //	[m_vertexArray appendBytes:newNormal length:(sizeof(GLfloat) * 3)];	
}

- (void)addVertex:(GLfloat *)newVertex;
{
	GLshort shortVertex[4];
	shortVertex[0] = (GLshort)MAX(MIN(round(newVertex[0] * 32767.0f), 32767), -32767);
	shortVertex[1] = (GLshort)MAX(MIN(round(newVertex[1] * 32767.0f), 32767), -32767);
	shortVertex[2] = (GLshort)MAX(MIN(round(newVertex[2] * 32767.0f), 32767), -32767);
	shortVertex[3] = 0;
	
    //	if ( ((newVertex[0] < -1.0f) || (newVertex[0] > 1.0f)) || ((newVertex[1] < -1.0f) || (newVertex[1] > 1.0f)) || ((newVertex[2] < -1.0f) || (newVertex[2] > 1.0f)) )
    //	{
    //		NSLog(@"Vertex outside range: %f, %f, %f", newVertex[0], newVertex[1], newVertex[2]);
    //	}
	
	[m_vertexArray appendBytes:shortVertex length:(sizeof(GLshort) * 4)];	
    
    //	[m_vertexArray appendBytes:newVertex length:(sizeof(GLfloat) * 3)];
	m_numVertices++;
	totalNumberOfVertices++;
}

- (void)addIndex:(GLushort *)newIndex;
{
	[m_indexArray appendBytes:newIndex length:sizeof(GLushort)];
	m_numIndices++;
}

- (void)addAtomToVertexBuffers:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint radiusScaleFactor:(float)radiusScaleFactor;
{
	GLfloat newVertex[3];
	GLubyte newColor[4];
	GLfloat atomRadius = 0.4f;
    
	// To avoid an overflow due to OpenGL ES's limit to unsigned short values in index buffers, we need to split vertices into multiple buffers
	if (m_numVertices > 65000)
	{
		[self addVertexBuffer];
	}
	GLushort baseToAddToIndices = m_numVertices;
    
    SLSAtomProperties currentAtomProperties = atomProperties[atomType];
    
    newColor[0] = currentAtomProperties.redComponent;
    newColor[1] = currentAtomProperties.greenComponent;
    newColor[2] = currentAtomProperties.blueComponent;
    newColor[3] = 1.0f;
    
    atomRadius = currentAtomProperties.atomRadius;

	atomRadius *= radiusScaleFactor;
    
	for (int currentCounter = 0; currentCounter < 12; currentCounter++)
	{
		// Adjust radius and shift to match center
		newVertex[0] = (vdata[currentCounter][0] * atomRadius) + newPoint.x;
		newVertex[1] = (vdata[currentCounter][1] * atomRadius) + newPoint.y;
		newVertex[2] = (vdata[currentCounter][2] * atomRadius) + newPoint.z;
        
		// Add vertex from table
		[self addVertex:newVertex];
        
		// Just use original icosahedron for normals
		newVertex[0] = vdata[currentCounter][0];
		newVertex[1] = vdata[currentCounter][1];
		newVertex[2] = vdata[currentCounter][2];
		
		// Add sphere normal
		[self addNormal:newVertex];		
	}
	
	GLushort indexHolder;
	for (int currentCounter = 0; currentCounter < 20; currentCounter++)
	{
		totalNumberOfTriangles++;
		for (unsigned int internalCounter = 0; internalCounter < 3; internalCounter++)
		{
			indexHolder = baseToAddToIndices + tindices[currentCounter][internalCounter];
			[self addIndex:&indexHolder];
		}
	}	
}

- (void)addBondToVertexBuffersWithStartPoint:(SLS3DPoint)startPoint endPoint:(SLS3DPoint)endPoint bondColor:(GLubyte *)bondColor bondType:(SLSBondType)bondType radiusScaleFactor:(float)radiusScaleFactor;
{
    //	SLS3DPoint startPoint, endPoint;
    //	if ( (startValue == nil) || (endValue == nil) )
    //		return;
    //	[startValue getValue:&startPoint];
    //	[endValue getValue:&endPoint];
    
	GLfloat bondRadius = 0.10;
	bondRadius *= radiusScaleFactor;
    
	GLfloat xDifference = endPoint.x - startPoint.x;
	GLfloat yDifference = endPoint.y - startPoint.y;
	GLfloat zDifference = endPoint.z - startPoint.z;
	GLfloat xyHypotenuse = sqrt(xDifference * xDifference + yDifference * yDifference);
	GLfloat xzHypotenuse = sqrt(xDifference * xDifference + zDifference * zDifference);
    
	// To avoid an overflow due to OpenGL ES's limit to unsigned short values in index buffers, we need to split vertices into multiple buffers
	if (m_numVertices > 65000)
	{
		[self addVertexBuffer];
	}
	GLushort baseToAddToIndices = m_numVertices;
	
	
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
		[self addVertex:edgeVertex];
        
		edgeNormal[0] = calculatedNormal.x;
		edgeNormal[1] = calculatedNormal.y;
		edgeNormal[2] = calculatedNormal.z;
		
		[self addNormal:edgeNormal];
		
		edgeVertex[0] = (calculatedNormal.x * bondRadius) + endPoint.x;
		edgeVertex[1] = (calculatedNormal.y * bondRadius) + endPoint.y;
		edgeVertex[2] = (calculatedNormal.z * bondRadius) + endPoint.z;
		[self addVertex:edgeVertex];
		[self addNormal:edgeNormal];
	}
    
	for (unsigned int currentCounter = 0; currentCounter < 8; currentCounter++)
	{
		totalNumberOfTriangles++;
        
		for (unsigned int internalCounter = 0; internalCounter < 3; internalCounter++)
		{
			GLushort indexHolder = baseToAddToIndices + bondIndices[currentCounter][internalCounter];
			[self addIndex:&indexHolder];
		}
	}
	
}

#pragma mark -
#pragma mark OpenGL drawing routines

- (void)addVertexBuffer;
{
	if (m_vertexArray != nil)
	{
		[m_vertexArray release];
		[m_indexArray release];
	}
	m_vertexArray = [[NSMutableData alloc] init];
	m_indexArray = [[NSMutableData alloc] init];
	m_numberOfVertexBuffers++;
	[m_vertexArrays addObject:m_vertexArray];
	[m_indexArrays addObject:m_indexArray];
	m_numVertices = 0;
	m_numIndices = 0;
}

- (void)bindVertexBuffersForMolecule;
{
	m_vertexBufferHandle = (GLuint *) malloc(sizeof(GLuint) * m_numberOfVertexBuffers);
	m_indexBufferHandle = (GLuint *) malloc(sizeof(GLuint) * m_numberOfVertexBuffers);
	if (m_numberOfIndicesForBuffers != NULL)
	{
		free(m_numberOfIndicesForBuffers);
        //		m_numberOfVertexBuffers = null;
	}
	
	m_numberOfIndicesForBuffers = (unsigned int *) malloc(sizeof(unsigned int) * m_numberOfVertexBuffers);
	
	for (unsigned int bufferIndex = 0; bufferIndex < m_numberOfVertexBuffers; bufferIndex++)
	{
		glGenBuffers(1, &m_indexBufferHandle[bufferIndex]); 
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_indexBufferHandle[bufferIndex]);   
        
		NSData *currentIndexBuffer = [m_indexArrays objectAtIndex:bufferIndex];
		GLushort *indexBuffer = (GLushort *)[currentIndexBuffer bytes];
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, [currentIndexBuffer length], indexBuffer, GL_STATIC_DRAW);     
        
		m_numberOfIndicesForBuffers[bufferIndex] = ([currentIndexBuffer length] / sizeof(GLushort));		
	}	
	// Now that the data is in the OpenGL buffer, can release the NSData
    
    [m_indexArray release];	
	m_indexArray = nil;
	[m_indexArrays release];
	m_indexArrays = nil;
	
	for (unsigned int bufferIndex = 0; bufferIndex < m_numberOfVertexBuffers; bufferIndex++)
	{	
		glGenBuffers(1, &m_vertexBufferHandle[bufferIndex]); 
		glBindBuffer(GL_ARRAY_BUFFER, m_vertexBufferHandle[bufferIndex]); 
        
		NSData *currentVertexBuffer = [m_vertexArrays objectAtIndex:bufferIndex];
		glBufferData(GL_ARRAY_BUFFER, [currentVertexBuffer length], (void *)[currentVertexBuffer bytes], GL_STATIC_DRAW); 
        
        //		glBindBuffer(GL_ARRAY_BUFFER, 0); 
	}
	[m_vertexArray release];
	m_vertexArray = nil;
	[m_vertexArrays release];	
	m_vertexArrays = nil;
}

- (void)drawMolecule;
{
	for (unsigned int bufferIndex = 0; bufferIndex < m_numberOfVertexBuffers; bufferIndex++)
	{
        glColor4f(1.0, 0.0, 0.0, 1.0);
        
		// Bind the buffers
		glBindBuffer(GL_ARRAY_BUFFER, m_vertexBufferHandle[bufferIndex]); 
		glVertexPointer(3, GL_SHORT, 16, (char *)NULL + 0); 		
		glNormalPointer(GL_SHORT, 16, (char *)NULL + 8); 
		
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_indexBufferHandle[bufferIndex]);    
        
		// Do the actual drawing to the screen
		glDrawElements(GL_TRIANGLES,m_numberOfIndicesForBuffers[bufferIndex],GL_UNSIGNED_SHORT, NULL);
		
		// Unbind the buffers
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
		glBindBuffer(GL_ARRAY_BUFFER, 0); 
	}
}

- (void)freeVertexBuffers;
{    
	for (unsigned int bufferIndex = 0; bufferIndex < m_numberOfVertexBuffers; bufferIndex++)
	{
		glDeleteBuffers(1, &m_indexBufferHandle[bufferIndex]);
		glDeleteBuffers(1, &m_vertexBufferHandle[bufferIndex]);
	}
    
	
	if (m_vertexBufferHandle != NULL)
	{
		free(m_vertexBufferHandle);
		m_vertexBufferHandle = NULL;
	}
	if (m_indexBufferHandle != NULL)
	{
		free(m_indexBufferHandle);
		m_indexBufferHandle = NULL;
	}
	if (m_numberOfIndicesForBuffers != NULL)
	{
		free(m_numberOfIndicesForBuffers);
		m_numberOfIndicesForBuffers = NULL;
	}
	
	totalNumberOfTriangles = 0;
	totalNumberOfVertices = 0;
}

- (void)initiateMoleculeRendering;
{
    m_vertexArrays = [[NSMutableArray alloc] init];
	m_indexArrays = [[NSMutableArray alloc] init];
    
	m_numberOfVertexBuffers = 0;
	[self addVertexBuffer];
}

- (void)terminateMoleculeRendering;
{
    m_numberOfVertexBuffers = 0;
    
    // Release all the NSData arrays that were partially generated
    [m_indexArray release];	
    m_indexArray = nil;
    [m_indexArrays release];
    
    [m_vertexArray release];
    m_vertexArray = nil;
    [m_vertexArrays release];
}


@end
