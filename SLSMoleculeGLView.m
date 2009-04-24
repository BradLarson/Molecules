//
//  SLSMoleculeGLView.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 5/18/2008.
//
//  This view manages the OpenGL scene, with setup and rendering methods.  Multitouch events are also handled
//  here, although it might be best to refactor some of the code up to a controller.


#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "SLSMoleculeGLView.h"
#import "SLSMolecule.h"

#define USE_DEPTH_BUFFER 1
//#define RUN_OPENGL_BENCHMARKS

// A class extension to declare private methods
@interface SLSMoleculeGLView ()

@property (nonatomic, retain) EAGLContext *context;

- (BOOL) createFramebuffer;
- (void) destroyFramebuffer;

@end


@implementation SLSMoleculeGLView

@synthesize context;

// You must implement this
+ (Class) layerClass 
{
	return [CAEAGLLayer class];
}


#pragma mark -
#pragma mark Initialization and breakdown

//The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder 
{
	if ((self = [super initWithCoder:coder])) 
	{
		self.multipleTouchEnabled = YES;
		
		// Do OpenGL Core Animation layer setup
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
		
		eaglLayer.opaque = YES;
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
		   [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
		
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
		
		if (!context || ![EAGLContext setCurrentContext:context] || ![self createFramebuffer]) 
		{
			[self release];
			return nil;
		}
		
//		NSData *matrixData = [[NSUserDefaults standardUserDefaults] objectForKey:@"matrixData"];
//		if (matrixData != nil)
//		{
//			float *currentModelViewMatrix = (float *)[matrixData bytes];
////			NSLog(@"Reading matrix");
////			NSLog(@"___________________________");
////			NSLog(@"|%f,%f,%f,%f|", currentModelViewMatrix[0], currentModelViewMatrix[1], currentModelViewMatrix[2], currentModelViewMatrix[3]);
////			NSLog(@"|%f,%f,%f,%f|", currentModelViewMatrix[4], currentModelViewMatrix[5], currentModelViewMatrix[6], currentModelViewMatrix[7]);
////			NSLog(@"|%f,%f,%f,%f|", currentModelViewMatrix[8], currentModelViewMatrix[9], currentModelViewMatrix[10], currentModelViewMatrix[11]);
////			NSLog(@"|%f,%f,%f,%f|", currentModelViewMatrix[12], currentModelViewMatrix[13], currentModelViewMatrix[14], currentModelViewMatrix[15]);
////			NSLog(@"___________________________");			
//		}

		previousScale = 1.0f;
		instantObjectScale = 1.0f;
		instantXRotation = 1.0f;
		instantYRotation = 0.0f;
		instantXTranslation = 0.0f;
		instantYTranslation = 0.0f;
		instantZTranslation = 0.0f;
		twoFingersAreMoving = NO;
		pinchGestureUnderway = NO;
		
//		[self drawViewByRotatingAroundX:0.0 rotatingAroundY:0.0 scaling:1.0 translationInX:0.0 translationInY:0.0];
		[self clearScreen];
		isFirstDrawingOfMolecule = YES;
		
		GLfixed currentModelViewMatrix[16]  = {45146,47441,2485,0,-25149,26775,-54274,0,-40303,36435,36650,0,0,0,0,65536};
		[self convertFixedPointMatrix:currentModelViewMatrix to3DTransform:&currentCalculatedMatrix];

		infoButton = [[UIButton buttonWithType:UIButtonTypeInfoLight] retain];
		infoButton.frame = CGRectMake(320 - 70, 460 - 70, 70, 70);
		[infoButton addTarget:self action:@selector(switchToTableView) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
		[self addSubview:infoButton];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleFinishOfMoleculeRendering:) name:@"MoleculeRenderingEnded" object:nil];

	}
	return self;
}

- (void)dealloc 
{
	// Read the current modelview matrix from OpenGL and save it in the user's preferences for recovery on next startup
	// TODO: save index, vertex, and normal buffers for quick reload later
	float currentModelViewMatrix[16];
	glMatrixMode(GL_MODELVIEW);
	glGetFloatv(GL_MODELVIEW_MATRIX, currentModelViewMatrix);	
	NSData *matrixData = [NSData dataWithBytes:currentModelViewMatrix length:(16 * sizeof(float))];	
	[[NSUserDefaults standardUserDefaults] setObject:matrixData forKey:@"matrixData"];	
	
	if ([EAGLContext currentContext] == context) 
	{
		[EAGLContext setCurrentContext:nil];
	}
	
	[context release];	

	[infoButton release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark OpenGL drawing

- (void)clearScreen;
{
	[EAGLContext setCurrentContext:context];
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];

}

- (void)drawView;
{
	if (moleculeToDisplay.isDoneRendering == NO)
		return;
	[self drawViewByRotatingAroundX:0.0f rotatingAroundY:0.0f scaling:1.0f translationInX:0.0f translationInY:0.0f];
}

- (void)drawViewByRotatingAroundX:(float)xRotation rotatingAroundY:(float)yRotation scaling:(float)scaleFactor translationInX:(float)xTranslation translationInY:(float)yTranslation;
{

	[EAGLContext setCurrentContext:context];
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glViewport(0, 0, backingWidth, backingHeight);
	glScissor(0, 0, backingWidth, backingHeight);
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrthof(-1.0f, 1.0f, -1.5f, 1.5f, -10.0f, 4.0f);
	
	GLfixed currentModelViewMatrix[16]  = {45146,47441,2485,0,-25149,26775,-54274,0,-40303,36435,36650,0,0,0,0,65536};
	glMatrixMode(GL_MODELVIEW);

	// Reset rotation system
	if (isFirstDrawingOfMolecule)
	{
		glLoadIdentity();
		glMultMatrixx(currentModelViewMatrix);
		[self configureLighting];
		
		isFirstDrawingOfMolecule = NO;
	}
	
	// Scale the view to fit current multitouch scaling
	currentCalculatedMatrix = CATransform3DScale(currentCalculatedMatrix, scaleFactor, scaleFactor, scaleFactor);
	
	// Perform incremental rotation based on current angles in X and Y	
	GLfloat totalRotation = sqrt(xRotation*xRotation + yRotation*yRotation);
	
	CATransform3D temporaryMatrix = CATransform3DRotate(currentCalculatedMatrix, totalRotation * M_PI / 180.0, 
												  ((xRotation/totalRotation) * currentCalculatedMatrix.m12 + (yRotation/totalRotation) * currentCalculatedMatrix.m11),
												  ((xRotation/totalRotation) * currentCalculatedMatrix.m22 + (yRotation/totalRotation) * currentCalculatedMatrix.m21),
												  ((xRotation/totalRotation) * currentCalculatedMatrix.m32 + (yRotation/totalRotation) * currentCalculatedMatrix.m31));
	if ((temporaryMatrix.m11 >= -100.0) && (temporaryMatrix.m11 <= 100.0))
		currentCalculatedMatrix = temporaryMatrix;
//	else
//		NSLog(@"Value out of range: %f", temporaryMatrix.m11);
		
	// Translate the model by the accumulated amount
	float currentScaleFactor = sqrt(pow(currentCalculatedMatrix.m11, 2.0f) + pow(currentCalculatedMatrix.m12, 2.0f) + pow(currentCalculatedMatrix.m13, 2.0f));	
	
	xTranslation = xTranslation / (currentScaleFactor * currentScaleFactor);
	yTranslation = yTranslation / (currentScaleFactor * currentScaleFactor);
	// Use the (0,4,8) components to figure the eye's X axis in the model coordinate system, translate along that
	temporaryMatrix = CATransform3DTranslate(currentCalculatedMatrix, xTranslation * currentCalculatedMatrix.m11, xTranslation * currentCalculatedMatrix.m21, xTranslation * currentCalculatedMatrix.m31);
	// Use the (1,5,9) components to figure the eye's Y axis in the model coordinate system, translate along that
	temporaryMatrix = CATransform3DTranslate(temporaryMatrix, yTranslation * currentCalculatedMatrix.m12, yTranslation * currentCalculatedMatrix.m22, yTranslation * currentCalculatedMatrix.m32);	
	
	if ((temporaryMatrix.m11 >= -100.0) && (temporaryMatrix.m11 <= 100.0))
		currentCalculatedMatrix = temporaryMatrix;
//	else
//		NSLog(@"Value out of range: %f", temporaryMatrix.m11);
	
	// Finally, set the new matrix that has been calculated from the Core Animation transform
	[self convert3DTransform:&currentCalculatedMatrix toFixedPointMatrix:currentModelViewMatrix];

	glLoadMatrixx(currentModelViewMatrix);
	
	// Black background, with depth buffer enabled
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	if (moleculeToDisplay.isDoneRendering)
		[moleculeToDisplay drawMolecule];
	
	// Draw buffered scene (?)
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void)configureLighting;
{
	const GLfixed			lightAmbient[] = {13107, 13107, 13107, 65535};
	const GLfixed			lightDiffuse[] = {65535, 65535, 65535, 65535};
	const GLfixed			matAmbient[] = {65535, 65535, 65535, 65535};
	const GLfixed			matDiffuse[] = {65535, 65535, 65535, 65535};	
	const GLfixed			lightPosition[] = {30535, -30535, 0, 0}; 
	const GLfixed			lightShininess = 20;	
	
	glEnable(GL_LIGHTING);
	glEnable(GL_LIGHT0);
	glEnable(GL_COLOR_MATERIAL);
	glMaterialxv(GL_FRONT_AND_BACK, GL_AMBIENT, matAmbient);
	glMaterialxv(GL_FRONT_AND_BACK, GL_DIFFUSE, matDiffuse);
	glMaterialx(GL_FRONT_AND_BACK, GL_SHININESS, lightShininess);
	glLightxv(GL_LIGHT0, GL_AMBIENT, lightAmbient);
	glLightxv(GL_LIGHT0, GL_DIFFUSE, lightDiffuse);
	glLightxv(GL_LIGHT0, GL_POSITION, lightPosition); 		
	
	glEnable(GL_DEPTH_TEST);
	
	glShadeModel(GL_SMOOTH);
	glEnable(GL_NORMALIZE);			
}

- (void)handleFinishOfMoleculeRendering:(NSNotification *)note;
{
	[self drawView];
#ifdef RUN_OPENGL_BENCHMARKS
	NSLog(NSLocalizedStringFromTable(@"Triangles: %d", @"Localized", nil), moleculeToDisplay.totalNumberOfTriangles);
	NSLog(NSLocalizedStringFromTable(@"Vertices: %d", @"Localized", nil), moleculeToDisplay.totalNumberOfVertices);
	CFAbsoluteTime elapsedTime, startTime = CFAbsoluteTimeGetCurrent();
	unsigned int testCounter;
	for (testCounter = 0; testCounter < 100; testCounter++)
	{
		// Do something		
		[self drawViewByRotatingAroundX:1.0f rotatingAroundY:0.0f scaling:1.0f translationInX:0.0f translationInY:0.0f];
	}
	elapsedTime = CFAbsoluteTimeGetCurrent() - startTime;
	// ElapsedTime contains seconds (or fractions thereof as decimals)
	NSLog(NSLocalizedStringFromTable(@"Elapsed time: %f", @"Localized", nil), elapsedTime);
#endif
	
}

- (void)convertFixedPointMatrix:(GLfixed *)fixedPointMatrix to3DTransform:(CATransform3D *)transform3D;
{
	transform3D->m11 = (CGFloat)fixedPointMatrix[0] / 65536.0f;
	transform3D->m12 = (CGFloat)fixedPointMatrix[1] / 65536.0f;
	transform3D->m13 = (CGFloat)fixedPointMatrix[2] / 65536.0f;
	transform3D->m14 = (CGFloat)fixedPointMatrix[3] / 65536.0f;
	transform3D->m21 = (CGFloat)fixedPointMatrix[4] / 65536.0f;
	transform3D->m22 = (CGFloat)fixedPointMatrix[5] / 65536.0f;
	transform3D->m23 = (CGFloat)fixedPointMatrix[6] / 65536.0f;
	transform3D->m24 = (CGFloat)fixedPointMatrix[7] / 65536.0f;
	transform3D->m31 = (CGFloat)fixedPointMatrix[8] / 65536.0f;
	transform3D->m32 = (CGFloat)fixedPointMatrix[9] / 65536.0f;
	transform3D->m33 = (CGFloat)fixedPointMatrix[10] / 65536.0f;
	transform3D->m34 = (CGFloat)fixedPointMatrix[11] / 65536.0f;
	transform3D->m41 = (CGFloat)fixedPointMatrix[12] / 65536.0f;
	transform3D->m42 = (CGFloat)fixedPointMatrix[13] / 65536.0f;
	transform3D->m43 = (CGFloat)fixedPointMatrix[14] / 65536.0f;
	transform3D->m44 = (CGFloat)fixedPointMatrix[15] / 65536.0f;
}

- (void)convert3DTransform:(CATransform3D *)transform3D toFixedPointMatrix:(GLfixed *)fixedPointMatrix;
{
//	struct CATransform3D
//	{
//		CGFloat m11, m12, m13, m14;
//		CGFloat m21, m22, m23, m24;
//		CGFloat m31, m32, m33, m34;
//		CGFloat m41, m42, m43, m44;
//	};
	
	fixedPointMatrix[0] = (GLfixed)(transform3D->m11 * 65536.0);
	fixedPointMatrix[1] = (GLfixed)(transform3D->m12 * 65536.0);
	fixedPointMatrix[2] = (GLfixed)(transform3D->m13 * 65536.0);
	fixedPointMatrix[3] = (GLfixed)(transform3D->m14 * 65536.0);
	fixedPointMatrix[4] = (GLfixed)(transform3D->m21 * 65536.0);
	fixedPointMatrix[5] = (GLfixed)(transform3D->m22 * 65536.0);
	fixedPointMatrix[6] = (GLfixed)(transform3D->m23 * 65536.0);
	fixedPointMatrix[7] = (GLfixed)(transform3D->m24 * 65536.0);
	fixedPointMatrix[8] = (GLfixed)(transform3D->m31 * 65536.0);
	fixedPointMatrix[9] = (GLfixed)(transform3D->m32 * 65536.0);
	fixedPointMatrix[10] = (GLfixed)(transform3D->m33 * 65536.0);
	fixedPointMatrix[11] = (GLfixed)(transform3D->m34 * 65536.0);
	fixedPointMatrix[12] = (GLfixed)(transform3D->m41 * 65536.0);
	fixedPointMatrix[13] = (GLfixed)(transform3D->m42 * 65536.0);
	fixedPointMatrix[14] = (GLfixed)(transform3D->m43 * 65536.0);
	fixedPointMatrix[15] = (GLfixed)(transform3D->m44 * 65536.0);
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

- (void)printFixedPointMatrix:(GLfixed *)fixedPointMatrix;
{
	NSLog(@"___________________________");
	NSLog(@"|%d,%d,%d,%d|", fixedPointMatrix[0], fixedPointMatrix[1], fixedPointMatrix[2], fixedPointMatrix[3]);
	NSLog(@"|%d,%d,%d,%d|", fixedPointMatrix[4], fixedPointMatrix[5], fixedPointMatrix[6], fixedPointMatrix[7]);
	NSLog(@"|%d,%d,%d,%d|", fixedPointMatrix[8], fixedPointMatrix[9], fixedPointMatrix[10], fixedPointMatrix[11]);
	NSLog(@"|%d,%d,%d,%d|", fixedPointMatrix[12], fixedPointMatrix[13], fixedPointMatrix[14], fixedPointMatrix[15]);
	NSLog(@"___________________________");			
}

- (void)layoutSubviews 
{
	[EAGLContext setCurrentContext:context];
	[self destroyFramebuffer];
	[self createFramebuffer];
	[self drawView];
}

- (BOOL)createFramebuffer 
{	
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
	if (USE_DEPTH_BUFFER) {
		glGenRenderbuffersOES(1, &depthRenderbuffer);
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
		glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
		glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
	}

	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) 
	{
		return NO;
	}
	
	return YES;
}

- (void)destroyFramebuffer 
{
	
	glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
	
	if(depthRenderbuffer) {
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
}

#pragma mark -
#pragma mark Touch handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSMutableSet *currentTouches = [[[event touchesForView:self] mutableCopy] autorelease];
    [currentTouches minusSet:touches];
	
	// New touches are not yet included in the current touches for the view
	NSSet *totalTouches = [touches setByAddingObjectsFromSet:[event touchesForView:self]];
	if ([totalTouches count] > 1)
	{
		startingTouchDistance = [self distanceBetweenTouches:totalTouches];
		previousScale = 1.0f;
		previousDirectionOfPanning = CGPointMake(0.0f, 0.0f);
	}
	else
	{
		lastMovementPosition = [[touches anyObject] locationInView:self];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
	if ([[event touchesForView:self] count] > 1) // Pinch gesture, possibly two-finger movement
	{
		CGPoint directionOfPanning = CGPointZero;
		
		// Two finger panning
		if ([touches count] > 1) // Check to make sure that both fingers are moving
		{
			directionOfPanning = [self commonDirectionOfTouches:touches];
		}
		
		if ( (directionOfPanning.x != 0) || (directionOfPanning.y != 0) ) // Don't scale while doing the two-finger panning
		{
			if (pinchGestureUnderway)
			{
				if (sqrt(previousDirectionOfPanning.x * previousDirectionOfPanning.x + previousDirectionOfPanning.y * previousDirectionOfPanning.y) > 0.1 )
				{
					pinchGestureUnderway = NO;
				}
				previousDirectionOfPanning.x += directionOfPanning.x;
				previousDirectionOfPanning.y += directionOfPanning.y;
			}
			if (!pinchGestureUnderway)
			{
				twoFingersAreMoving = YES;
				[self drawViewByRotatingAroundX:0.0f rotatingAroundY:0.0f scaling:1.0f translationInX:directionOfPanning.x translationInY:directionOfPanning.y];
				previousDirectionOfPanning = CGPointZero;
			}
		}
		else
		{
			float newTouchDistance = [self distanceBetweenTouches:[event touchesForView:self]];
			if (twoFingersAreMoving)
			{
				// If fingers have moved more than 10% apart, start pinch gesture again
				if ( fabs(1 - (newTouchDistance / startingTouchDistance) / previousScale) > 0.3 )
				{
					twoFingersAreMoving = NO;
				}
			}
			if (!twoFingersAreMoving)
			{
				// Scale using pinch gesture
				[self drawViewByRotatingAroundX:0.0 rotatingAroundY:0.0 scaling:(newTouchDistance / startingTouchDistance) / previousScale translationInX:directionOfPanning.x translationInY:directionOfPanning.y];
				previousScale = (newTouchDistance / startingTouchDistance);
				pinchGestureUnderway = YES;
			}
		}
	}
	else // Single-touch rotation of object
	{
		CGPoint currentMovementPosition = [[touches anyObject] locationInView:self];
		[self drawViewByRotatingAroundX:(currentMovementPosition.x - lastMovementPosition.x) rotatingAroundY:(currentMovementPosition.y - lastMovementPosition.y) scaling:1.0f translationInX:0.0f translationInY:0.0f];
		lastMovementPosition = currentMovementPosition;
	}
	
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
//	if ([[touches anyObject] tapCount] >= 2) 
//	{
//		// Double-touch toggles the views
//		[self.delegate toggleView];
//	}
	if ([[touches anyObject] tapCount] >= 2)
	{
		NSString *buttonTitle1;
		NSString *buttonTitle2;
		NSString *cancelButtonTitle;
		switch (moleculeToDisplay.currentVisualizationType)
		{
			case BALLANDSTICK:
			{
				buttonTitle1 = NSLocalizedStringFromTable(@"Spacefilling", @"Localized", nil);
				buttonTitle2 = NSLocalizedStringFromTable(@"Cylinders", @"Localized", nil);
				cancelButtonTitle = NSLocalizedStringFromTable(@"Ball-and-stick", @"Localized", nil);
			}; break;
			case SPACEFILLING:
			{
				buttonTitle1 = NSLocalizedStringFromTable(@"Ball-and-stick", @"Localized", nil);
				buttonTitle2 = NSLocalizedStringFromTable(@"Cylinders", @"Localized", nil);
				cancelButtonTitle = NSLocalizedStringFromTable(@"Spacefilling", @"Localized", nil);
			}; break;
			case CYLINDRICAL:
			{
				buttonTitle1 = NSLocalizedStringFromTable(@"Ball-and-stick", @"Localized", nil);
				buttonTitle2 = NSLocalizedStringFromTable(@"Spacefilling", @"Localized", nil);
				cancelButtonTitle = NSLocalizedStringFromTable(@"Cylinders", @"Localized", nil);
			}; break;
		}

		// If the rendering process has not finished, prevent you from changing the visualization mode
		if (moleculeToDisplay.isDoneRendering == YES)
		{
			UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedStringFromTable(@"Visualization mode", @"Localized", nil)
																	 delegate:self cancelButtonTitle:cancelButtonTitle destructiveButtonTitle:nil
															otherButtonTitles:buttonTitle1, buttonTitle2, nil];
			actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
			[actionSheet showInView:self];
			[actionSheet release];
		}		
	}
	else if ([[touches anyObject] tapCount] >= 1)
	{
		// Check for touches near the information button, because hits aren't being registered properly
		CGPoint currentTouchPosition = [[touches anyObject] locationInView:self];
		if ( (currentTouchPosition.x > 268) && (currentTouchPosition.y > 410) )
			[self.delegate toggleView];
	}
	
    NSMutableSet *remainingTouches = [[[event touchesForView:self] mutableCopy] autorelease];
    [remainingTouches minusSet:touches];
	if ([remainingTouches count] < 2)
	{
		twoFingersAreMoving = NO;
		pinchGestureUnderway = NO;
		previousDirectionOfPanning = CGPointZero;

		lastMovementPosition = [[remainingTouches anyObject] locationInView:self];
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event 
{
	// Handle touches canceled the same as as a touches ended event
    [self touchesEnded:touches withEvent:event];
}

- (float)distanceBetweenTouches:(NSSet *)touches;
{
	int currentStage = 0;
	CGPoint point1, point2;
	
	
	for (UITouch *currentTouch in touches)
	{
		if (currentStage == 0)
		{
			point1 = [currentTouch locationInView:self];
			currentStage++;
		}
		else if (currentStage == 1) 
		{
			point2 = [currentTouch locationInView:self];
			currentStage++;
		}
		else
		{
		}
	}
	return (sqrt((point1.x - point2.x) * (point1.x - point2.x) + (point1.y - point2.y) * (point1.y - point2.y)));
}

- (CGPoint)commonDirectionOfTouches:(NSSet *)touches;
{
	
	// Check to make sure that both fingers are moving in the same direction
	// Get vector for

	int currentStage = 0;
	CGPoint currentLocationOfTouch1, currentLocationOfTouch2, previousLocationOfTouch1, previousLocationOfTouch2;
	
	
	for (UITouch *currentTouch in touches)
	{
		if (currentStage == 0)
		{
			previousLocationOfTouch1 = [currentTouch previousLocationInView:self];
			currentLocationOfTouch1 = [currentTouch locationInView:self];
			currentStage++;
		}
		else if (currentStage == 1) 
		{
			previousLocationOfTouch2 = [currentTouch previousLocationInView:self];
			currentLocationOfTouch2 = [currentTouch locationInView:self];
			currentStage++;
		}
		else
		{
		}
	}
	
	CGPoint directionOfTouch1, directionOfTouch2, commonDirection;
	// The sign of the Y touches is inverted, due to the inverted coordinate system of the iPhone
	directionOfTouch1.x = currentLocationOfTouch1.x - previousLocationOfTouch1.x;
	directionOfTouch1.y = previousLocationOfTouch1.y - currentLocationOfTouch1.y;
	directionOfTouch2.x = currentLocationOfTouch2.x - previousLocationOfTouch2.x;
	directionOfTouch2.y = previousLocationOfTouch2.y - currentLocationOfTouch2.y;	
	
	// A two-finger movement should result in the direction of both touches being positive or negative at the same time in X and Y
	if (!( (directionOfTouch1.x <= 0) && (directionOfTouch2.x <= 0) || (directionOfTouch1.x >= 0) && (directionOfTouch2.x >= 0) ))
		return CGPointZero;
	if (!( (directionOfTouch1.y <= 0) && (directionOfTouch2.y <= 0) || (directionOfTouch1.y >= 0) && (directionOfTouch2.y >= 0) ))
		return CGPointZero;
	
	// The movement ranges are averaged out 
	commonDirection.x = ((directionOfTouch1.x + directionOfTouch1.x) / 2.0f) / 240.0f;
	commonDirection.y = ((directionOfTouch1.y + directionOfTouch1.y) / 2.0f) / 240.0f;
	
	return commonDirection;
}

- (IBAction)switchToTableView;
{
	[self.delegate toggleView];
}

#pragma mark -
#pragma mark UIActionSheet delegate method

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	SLSVisualizationType newVisualizationType = moleculeToDisplay.currentVisualizationType;
	switch (moleculeToDisplay.currentVisualizationType)
	{
		case BALLANDSTICK:
		{
			if (buttonIndex == 0)
				newVisualizationType = SPACEFILLING;
			else if (buttonIndex == 1)
				newVisualizationType = CYLINDRICAL;
		}; break;
		case SPACEFILLING:
		{
			if (buttonIndex == 0)
				newVisualizationType = BALLANDSTICK;
			else if (buttonIndex == 1)
				newVisualizationType = CYLINDRICAL;
		}; break;
		case CYLINDRICAL:
		{
			if (buttonIndex == 0)
				newVisualizationType = BALLANDSTICK;
			else if (buttonIndex == 1)
				newVisualizationType = SPACEFILLING;
		}; break;
	}
	
	moleculeToDisplay.currentVisualizationType = newVisualizationType;
}

#pragma mark -
#pragma mark Accessors

@synthesize moleculeToDisplay;
@synthesize delegate;

- (void)setMoleculeToDisplay:(SLSMolecule *)newMolecule;
{
	if (moleculeToDisplay == newMolecule)
	{
		return;
	}

	moleculeToDisplay.isBeingDisplayed = NO;
	[moleculeToDisplay release];
	moleculeToDisplay = [newMolecule retain];
	moleculeToDisplay.isBeingDisplayed = YES;
	
	isFirstDrawingOfMolecule = YES;
	
	instantObjectScale = 1.0f;
	instantXRotation = 1.0f;
	instantYRotation = 0.0f;
	instantXTranslation = 0.0f;
	instantYTranslation = 0.0f;
	instantZTranslation = 0.0f;

	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end
