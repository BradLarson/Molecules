//
//  SLSOpenGLES11Renderer.h
//  Molecules
//
//  Created by Brad Larson on 4/12/2011.
//  Copyright 2011 Sunset Lake Software LLC. All rights reserved.
//

#import "SLSOpenGLESRenderer.h"

@interface SLSOpenGLES11Renderer : SLSOpenGLESRenderer 
{
    // OpenGL vertex buffer objects
	unsigned int *m_numberOfIndicesForBuffers;
	GLuint *m_vertexBufferHandle, *m_indexBufferHandle;
	NSMutableArray *m_vertexArrays, *m_indexArrays;
	unsigned int m_numberOfVertexBuffers;
	NSMutableData *m_vertexArray, *m_indexArray;
	unsigned int m_numVertices, m_numIndices;
}

@end
