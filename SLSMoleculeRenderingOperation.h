//
//  SLSMoleculeRenderingOperation.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 8/22/2009.
//
//  This is an operation that manages the rendering of molecules.

#import <Foundation/Foundation.h>

@class SLSMoleculeGLViewController;

@interface SLSMoleculeRenderingOperation : NSOperation 
{
	SLSMoleculeGLViewController *glViewController;
	NSInteger stepsSinceLastRotation;
}

// Initialization and teardown
- (id)initWithViewController:(SLSMoleculeGLViewController *)newGLViewController;

@end
