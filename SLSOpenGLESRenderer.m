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
#pragma mark OpenGL drawing

- (BOOL)createFramebuffersForLayer:(CAEAGLLayer *)glLayer;
{
    return YES;
}

- (void)destroyFramebuffer;
{
    
}

- (void)configureLighting;
{
    
}

- (void)clearScreen;
{
    
}

- (void)startDrawingFrame;
{
    
}

- (void)configureProjection;
{
    
}

- (void)presentRenderBuffer;
{
    
}

#pragma mark -
#pragma mark Accessors

@synthesize context;


@end
