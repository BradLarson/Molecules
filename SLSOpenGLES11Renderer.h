//
//  SLSOpenGLES11Renderer.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 4/12/2011.
//
//  This is the old renderer, split out into a separate class for OpenGL ES 1.1 devices

#import "SLSOpenGLESRenderer.h"

@interface SLSOpenGLES11Renderer : SLSOpenGLESRenderer 
{
}

// Molecule 3-D geometry generation
- (void)addNormal:(GLfloat *)newNormal forAtomType:(SLSAtomType)atomType;
- (void)addBondNormal:(GLfloat *)newNormal;

@end
