//
//  SLSMoleculeRenderingOperation.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 8/22/2009.
//
//  This is an operation that manages the rendering of molecules.

#import "SLSMoleculeRenderingOperation.h"
#import "SLSMoleculeGLViewController.h"

@implementation SLSMoleculeRenderingOperation

#pragma mark -
#pragma mark Initialization and teardown
//- (void)drawViewByRotatingAroundX:(float)xRotation rotatingAroundY:(float)yRotation scaling:(float)scaleFactor translationInX:(float)xTranslation translationInY:(float)yTranslation;

- (id)initWithViewController:(SLSMoleculeGLViewController *)newGLViewController;
{
	if ([super init])
	{
		glViewController = newGLViewController;
	}
	
	return self;
}

#pragma mark -
#pragma mark Central processing

- (void)main
{
//	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if (![self isCancelled])
	{
		[glViewController drawViewByRotatingAroundX:(1.0 + (float)stepsSinceLastRotation * 1.0) rotatingAroundY:0.0f scaling:1.0f translationInX:0.0f translationInY:0.0f];
	}
//	[pool release];
}

@end
