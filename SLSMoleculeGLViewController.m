//
//  SLSMoleculeGLViewController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/30/2008.
//
//  A barebones controller for managing the OpenGL view of the molecule.  It's pretty sparse, as some of the methods in the view really belong here.

#import "SLSMoleculeGLViewController.h"
#import "SLSMoleculeGLView.h"
#import "SLSMolecule.h"
#import "SLSMoleculeAutorotationOperation.h"

@implementation SLSMoleculeGLViewController

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) 
	{
		// Set up an observer that catches the molecule update notifications and shows and updates the rendering indicator
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(showRenderingIndicator:) name:@"MoleculeRenderingStarted" object:nil];
		[nc addObserver:self selector:@selector(updateRenderingIndicator:) name:@"MoleculeRenderingUpdate" object:nil];
		[nc addObserver:self selector:@selector(hideRenderingIndicator:) name:@"MoleculeRenderingEnded" object:nil];
		
		[nc addObserver:self selector:@selector(showScanningIndicator:) name:@"FileLoadingStarted" object:nil];
		[nc addObserver:self selector:@selector(updateScanningIndicator:) name:@"FileLoadingUpdate" object:nil];
		[nc addObserver:self selector:@selector(hideScanningIndicator:) name:@"FileLoadingEnded" object:nil];
		
		isAutorotating = NO;
		
		// Initialize values for the touch interaction
		previousScale = 1.0f;
		instantObjectScale = 1.0f;
		instantXRotation = 1.0f;
		instantYRotation = 0.0f;
		instantXTranslation = 0.0f;
		instantYTranslation = 0.0f;
		instantZTranslation = 0.0f;
		twoFingersAreMoving = NO;
		pinchGestureUnderway = NO;

		// Set up the initial model view matrix for the rendering
		isFirstDrawingOfMolecule = YES;
		isFrameRenderingFinished = YES;
		
		GLfloat currentModelViewMatrix[16]  = {0.402560,0.094840,0.910469,0.000000, 0.913984,-0.096835,-0.394028,0.000000, 0.050796,0.990772,-0.125664,0.000000, 0.000000,0.000000,0.000000,1.000000};
		
		//		GLfloat currentModelViewMatrix[16]  = {1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0};
		
		[self convertMatrix:currentModelViewMatrix to3DTransform:&currentCalculatedMatrix];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleFinishOfMoleculeRendering:) name:@"MoleculeRenderingEnded" object:nil];
		
		autorotationQueue = [[NSOperationQueue alloc] init];
	}
	return self;
}

- (void)dealloc 
{
	[rotationButton release];
	[autorotationQueue release];
	[super dealloc];
}

- (void)viewDidLoad 
{
	SLSMoleculeGLView *glView = [[SLSMoleculeGLView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	UIButton *infoButton = [[UIButton buttonWithType:UIButtonTypeInfoLight] retain];
	infoButton.frame = CGRectMake(320.0f - 70.0f, 460.0f - 70.0f, 70.0f, 70.0f);
	[infoButton addTarget:self action:@selector(switchToTableView) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
	[glView addSubview:infoButton];
	[infoButton release];

	rotationButton = [UIButton buttonWithType:UIButtonTypeCustom];
	
	UIImage *rotationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RotationIcon" ofType:@"png"]];
	[rotationButton setImage:rotationImage forState:UIControlStateNormal];
	[rotationImage release];

	UIImage *selectedRotationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RotationIconSelected" ofType:@"png"]];
	[rotationButton setImage:selectedRotationImage forState:UIControlStateSelected];
	[selectedRotationImage release];
	
	rotationButton.showsTouchWhenHighlighted = YES;
	[rotationButton addTarget:self action:@selector(startOrStopAutorotation:) forControlEvents:UIControlEventTouchUpInside];
	rotationButton.frame = CGRectMake(0.0f, 460.0f - 70.0f, 70.0f, 70.0f);
	rotationButton.clipsToBounds = NO;
	[glView addSubview:rotationButton];
	
	self.view = glView;
	
	[glView release];
}

#pragma mark -
#pragma mark Display indicator control

- (void)showScanningIndicator:(NSNotification *)note;
{
	scanningActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	scanningActivityIndicator.frame = CGRectMake(142.0f, 212.0f, 37.0f, 37.0f);
	scanningActivityIndicator.hidesWhenStopped = YES;
	[scanningActivityIndicator startAnimating];
	
	renderingActivityLabel = [[UILabel alloc] initWithFrame:CGRectMake(51.0f, 176.0f, 219.0f, 21.0f)];
	renderingActivityLabel.font = [UIFont systemFontOfSize:17.0f];
	renderingActivityLabel.text = [note object];
	renderingActivityLabel.textAlignment = UITextAlignmentCenter;
	renderingActivityLabel.backgroundColor = [UIColor clearColor];
	renderingActivityLabel.textColor = [UIColor whiteColor];
	
	[self.view addSubview:scanningActivityIndicator];
	[self.view addSubview:renderingActivityLabel];
}

- (void)updateScanningIndicator:(NSNotification *)note;
{
	
}

- (void)hideScanningIndicator:(NSNotification *)note;
{
	[renderingActivityLabel removeFromSuperview];
	[renderingActivityLabel release];
	renderingActivityLabel = nil;
	
	[scanningActivityIndicator removeFromSuperview];
	[scanningActivityIndicator release];
	scanningActivityIndicator = nil;
}

- (void)showRenderingIndicator:(NSNotification *)note;
{
	renderingProgressIndicator = [[UIProgressView alloc] initWithFrame:CGRectMake(85.0f, 226.0f, 150.0f, 9.0f)];
	[renderingProgressIndicator setProgress:0.0f];
	
	renderingActivityLabel = [[UILabel alloc] initWithFrame:CGRectMake(51.0f, 176.0f, 219.0f, 21.0f)];
	renderingActivityLabel.font = [UIFont systemFontOfSize:17.0f];
	renderingActivityLabel.text = NSLocalizedStringFromTable(@"Rendering...", @"Localized", nil);
	renderingActivityLabel.textAlignment = UITextAlignmentCenter;
	renderingActivityLabel.backgroundColor = [UIColor clearColor];
	renderingActivityLabel.textColor = [UIColor whiteColor];

	[(SLSMoleculeGLView *)self.view clearScreen];
	[renderingProgressIndicator setProgress:0.0];
	[self.view addSubview:renderingProgressIndicator];
	[self.view addSubview:renderingActivityLabel];
}

- (void)updateRenderingIndicator:(NSNotification *)note;
{
	float percentComplete = [(NSNumber *)[note object] floatValue];
	
	if ((percentComplete - renderingProgressIndicator.progress) > 0.01f)
	{
		renderingProgressIndicator.progress = percentComplete;
	}
}

- (void)hideRenderingIndicator:(NSNotification *)note;
{
	[renderingActivityLabel removeFromSuperview];
	[renderingProgressIndicator removeFromSuperview];

	[renderingActivityLabel release];
	renderingActivityLabel = nil;
	
	[renderingProgressIndicator release];
	renderingProgressIndicator = nil;
}

#pragma mark -
#pragma mark Autorotation of molecule

- (void)startOrStopAutorotation:(id)sender;
{
	if (isAutorotating)
	{
		[autorotationQueue cancelAllOperations];
		[autorotationQueue waitUntilAllOperationsAreFinished];
		rotationButton.selected = NO;
	}
	else
	{
		rotationButton.selected = YES;
		SLSMoleculeAutorotationOperation *autorotationOperation = [[SLSMoleculeAutorotationOperation alloc] initWithViewController:self];
		[autorotationQueue addOperation:autorotationOperation];
		[autorotationOperation release];
	}
	isAutorotating = !isAutorotating;
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

#pragma mark -
#pragma mark OpenGL molecule rendering

- (void)drawView;
{
	if (moleculeToDisplay.isDoneRendering == NO)
		return;
	
	GLfloat currentModelViewMatrix[16]  = {0.402560,0.094840,0.910469,0.000000, 0.913984,-0.096835,-0.394028,0.000000, 0.050796,0.990772,-0.125664,0.000000, 0.000000,0.000000,0.000000,1.000000};
	[self convertMatrix:currentModelViewMatrix to3DTransform:&currentCalculatedMatrix];
	
	[self drawViewByRotatingAroundX:0.0f rotatingAroundY:0.0f scaling:1.0f translationInX:0.0f translationInY:0.0f];
}

- (void)drawViewByRotatingAroundX:(float)xRotation rotatingAroundY:(float)yRotation scaling:(float)scaleFactor translationInX:(float)xTranslation translationInY:(float)yTranslation;
{
	isFrameRenderingFinished = NO;
	
	SLSMoleculeGLView *glView = (SLSMoleculeGLView *)self.view;
	
	[glView startDrawingFrame];
	
	if (isFirstDrawingOfMolecule)
	{
		[glView configureProjection];
	}
	
	GLfloat currentModelViewMatrix[16]  = {0.402560,0.094840,0.910469,0.000000, 0.913984,-0.096835,-0.394028,0.000000, 0.050796,0.990772,-0.125664,0.000000, 0.000000,0.000000,0.000000,1.000000};
	
	glMatrixMode(GL_MODELVIEW);
	
	// Reset rotation system
	if (isFirstDrawingOfMolecule)
	{
		glLoadIdentity();
		glMultMatrixf(currentModelViewMatrix);
		[glView configureLighting];
		
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
	
	// Finally, set the new matrix that has been calculated from the Core Animation transform
	[self convert3DTransform:&currentCalculatedMatrix toMatrix:currentModelViewMatrix];
	
	glLoadMatrixf(currentModelViewMatrix);
	
	// Black background, with depth buffer enabled
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	if (moleculeToDisplay.isDoneRendering)
		[moleculeToDisplay drawMolecule];
	
	[glView presentRenderBuffer];
	isFrameRenderingFinished = YES;
}

- (void)runOpenGLBenchmarks;
{
	NSLog(NSLocalizedStringFromTable(@"Triangles: %d", @"Localized", nil), moleculeToDisplay.totalNumberOfTriangles);
	NSLog(NSLocalizedStringFromTable(@"Vertices: %d", @"Localized", nil), moleculeToDisplay.totalNumberOfVertices);
	CFAbsoluteTime elapsedTime, startTime = CFAbsoluteTimeGetCurrent();
#define NUMBER_OF_FRAMES_FOR_TESTING 100
	
	for (unsigned int testCounter = 0; testCounter < NUMBER_OF_FRAMES_FOR_TESTING; testCounter++)
	{
		// Do something		
		[self drawViewByRotatingAroundX:1.0f rotatingAroundY:0.0f scaling:1.0f translationInX:0.0f translationInY:0.0f];
	}
	elapsedTime = CFAbsoluteTimeGetCurrent() - startTime;
	// ElapsedTime contains seconds (or fractions thereof as decimals)
	NSLog(NSLocalizedStringFromTable(@"Elapsed time: %f", @"Localized", nil), elapsedTime);
	NSLog(@"Triangles per second: %f", (CGFloat)moleculeToDisplay.totalNumberOfTriangles * (CGFloat)NUMBER_OF_FRAMES_FOR_TESTING / elapsedTime);
}

#pragma mark -
#pragma mark Manage molecule rendering state

- (void)handleFinishOfMoleculeRendering:(NSNotification *)note;
{
	[(SLSMoleculeGLView *)self.view clearScreen];
	[NSThread sleepForTimeInterval:0.1];

	GLfloat currentModelViewMatrix[16]  = {0.402560,0.094840,0.910469,0.000000, 0.913984,-0.096835,-0.394028,0.000000, 0.050796,0.990772,-0.125664,0.000000, 0.000000,0.000000,0.000000,1.000000};
	[self convertMatrix:currentModelViewMatrix to3DTransform:&currentCalculatedMatrix];
	
#ifdef RUN_OPENGL_BENCHMARKS
	[self performSelector:@selector(runOpenGLBenchmarks) withObject:nil afterDelay:0.5];
#else
	[self startOrStopAutorotation:self];	
#endif	
}

#pragma mark -
#pragma mark Touch handling

- (float)distanceBetweenTouches:(NSSet *)touches;
{
	int currentStage = 0;
	CGPoint point1, point2;
	
	
	for (UITouch *currentTouch in touches)
	{
		if (currentStage == 0)
		{
			point1 = [currentTouch locationInView:self.view];
			currentStage++;
		}
		else if (currentStage == 1) 
		{
			point2 = [currentTouch locationInView:self.view];
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
	
	int currentStage = 0;
	CGPoint currentLocationOfTouch1, currentLocationOfTouch2, previousLocationOfTouch1, previousLocationOfTouch2;
	
	
	for (UITouch *currentTouch in touches)
	{
		if (currentStage == 0)
		{
			previousLocationOfTouch1 = [currentTouch previousLocationInView:self.view];
			currentLocationOfTouch1 = [currentTouch locationInView:self.view];
			currentStage++;
		}
		else if (currentStage == 1) 
		{
			previousLocationOfTouch2 = [currentTouch previousLocationInView:self.view];
			currentLocationOfTouch2 = [currentTouch locationInView:self.view];
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
	if (!( ((directionOfTouch1.x <= 0) && (directionOfTouch2.x <= 0)) || ((directionOfTouch1.x >= 0) && (directionOfTouch2.x >= 0)) ))
		return CGPointZero;
	if (!( ((directionOfTouch1.y <= 0) && (directionOfTouch2.y <= 0)) || ((directionOfTouch1.y >= 0) && (directionOfTouch2.y >= 0)) ))
		return CGPointZero;
	
	// The movement ranges are averaged out 
	commonDirection.x = ((directionOfTouch1.x + directionOfTouch1.x) / 2.0f) * 200.0f;
	commonDirection.y = ((directionOfTouch1.y + directionOfTouch1.y) / 2.0f) * 200.0f;
	

	return commonDirection;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (isAutorotating)
		[self startOrStopAutorotation:nil];

    NSMutableSet *currentTouches = [[[event touchesForView:self.view] mutableCopy] autorelease];
    [currentTouches minusSet:touches];
	
	// New touches are not yet included in the current touches for the view
	NSSet *totalTouches = [touches setByAddingObjectsFromSet:[event touchesForView:self.view]];
	if ([totalTouches count] > 1)
	{
		startingTouchDistance = [self distanceBetweenTouches:totalTouches];
		previousScale = 1.0f;
		twoFingersAreMoving = NO;
		pinchGestureUnderway = NO;
		previousDirectionOfPanning = CGPointZero;
	}
	else
	{
		lastMovementPosition = [[touches anyObject] locationInView:self.view];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
	if (isAutorotating)
		[self startOrStopAutorotation:nil];

	if ([[event touchesForView:self.view] count] > 1) // Pinch gesture, possibly two-finger movement
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
			float newTouchDistance = [self distanceBetweenTouches:[event touchesForView:self.view]];
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
		CGPoint currentMovementPosition = [[touches anyObject] locationInView:self.view];
		[self drawViewByRotatingAroundX:(currentMovementPosition.x - lastMovementPosition.x) rotatingAroundY:(currentMovementPosition.y - lastMovementPosition.y) scaling:1.0f translationInX:0.0f translationInY:0.0f];
		lastMovementPosition = currentMovementPosition;
	}
	
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
	if (isAutorotating)
		[self startOrStopAutorotation:nil];

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
			default:
			{
				buttonTitle1 = NSLocalizedStringFromTable(@"Spacefilling", @"Localized", nil);
				buttonTitle2 = NSLocalizedStringFromTable(@"Cylinders", @"Localized", nil);
				cancelButtonTitle = NSLocalizedStringFromTable(@"Ball-and-stick", @"Localized", nil);
			};
		}
		
		// If the rendering process has not finished, prevent you from changing the visualization mode
		if (moleculeToDisplay.isDoneRendering == YES)
		{
			UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedStringFromTable(@"Visualization mode", @"Localized", nil)
																	 delegate:self cancelButtonTitle:cancelButtonTitle destructiveButtonTitle:nil
															otherButtonTitles:buttonTitle1, buttonTitle2, nil];
			actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
			[actionSheet showInView:self.view];
			[actionSheet release];
		}		
	}
	
    NSMutableSet *remainingTouches = [[[event touchesForView:self.view] mutableCopy] autorelease];
    [remainingTouches minusSet:touches];
	if ([remainingTouches count] < 2)
	{
		twoFingersAreMoving = NO;
		pinchGestureUnderway = NO;
		previousDirectionOfPanning = CGPointZero;
		
		lastMovementPosition = [[remainingTouches anyObject] locationInView:self.view];
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event 
{
	// Handle touches canceled the same as as a touches ended event
    [self touchesEnded:touches withEvent:event];
}

#pragma mark -
#pragma mark Interface methods

- (IBAction)switchToTableView;
{
	if (moleculeToDisplay.isDoneRendering == NO)
	{
		return;
	}
	
	if (isAutorotating)
		[self startOrStopAutorotation:nil];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleView" object:nil];
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
#pragma mark UIViewController methods

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning 
{
}

#pragma mark -
#pragma mark Accessors

@synthesize moleculeToDisplay;
@synthesize isFrameRenderingFinished;

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
