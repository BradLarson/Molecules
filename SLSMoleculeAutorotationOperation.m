//
//  SLSMoleculeAutorotationOperation.m
//  Molecules
//
//  Created by Brad Larson on 8/22/2009.
//  Copyright 2009 Sunset Lake Software LLC. All rights reserved.
//

#import "SLSMoleculeAutorotationOperation.h"
#import "SLSMoleculeGLViewController.h"

@implementation SLSMoleculeAutorotationOperation

#pragma mark -
#pragma mark Initialization and teardown

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
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	float degreesCounter = 0.0f;
	
	while (!self.isCancelled)
	{
		[NSThread sleepForTimeInterval:1.0f / 30.0f];
		degreesCounter += 1.0f;
		if (glViewController.isFrameRenderingFinished)
		{
			[glViewController drawViewByRotatingAroundX:degreesCounter rotatingAroundY:0.0f scaling:1.0f translationInX:0.0f translationInY:0.0f];
			degreesCounter = 0.0f;
		}
	}
	[pool release];
}

@end
