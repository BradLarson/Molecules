//
//  SLSMoleculeGLViewController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/30/2008.
//
//  A barebones controller for managing the OpenGL view of the molecule.  It's pretty sparse, as some of the methods in the view really belong here.

#import <UIKit/UIKit.h>
#import <OpenGLES/ES1/gl.h>
#import <QuartzCore/QuartzCore.h>

@class SLSMolecule;

@interface SLSMoleculeGLViewController : UIViewController <UIActionSheetDelegate>
{	
	// User interface elements
	UIActivityIndicatorView *scanningActivityIndicator;
	UIProgressView *renderingProgressIndicator;
	UILabel *renderingActivityLabel;

	SLSMolecule *moleculeToDisplay;
	CATransform3D currentCalculatedMatrix;
	BOOL isAutorotating, isAutorotationCancelled;
	BOOL isFirstDrawingOfMolecule, isFrameRenderingFinished;

	// Touch-handling 
	float startingTouchDistance, previousScale;
	float instantObjectScale, instantXRotation, instantYRotation, instantXTranslation, instantYTranslation, instantZTranslation;
	CGPoint lastMovementPosition, previousDirectionOfPanning;
	BOOL twoFingersAreMoving, pinchGestureUnderway;
}

@property (readwrite, retain) SLSMolecule *moleculeToDisplay;

// Display indicator control
- (void)showScanningIndicator:(NSNotification *)note;
- (void)updateScanningIndicator:(NSNotification *)note;
- (void)hideScanningIndicator:(NSNotification *)note;
- (void)showRenderingIndicator:(NSNotification *)note;
- (void)updateRenderingIndicator:(NSNotification *)note;
- (void)hideRenderingIndicator:(NSNotification *)note;

// Autorotation of molecule
- (void)startOrStopAutorotation:(id)sender;
- (void)autoRotationThread;

// OpenGL matrix helper methods
- (void)convertMatrix:(GLfloat *)matrix to3DTransform:(CATransform3D *)transform3D;
- (void)convert3DTransform:(CATransform3D *)transform3D toMatrix:(GLfloat *)matrix;
- (void)print3DTransform:(CATransform3D *)transform3D;
- (void)printMatrix:(GLfloat *)fixedPointMatrix;


// OpenGL molecule rendering
- (void)drawView;
- (void)drawViewByRotatingAroundX:(float)xRotation rotatingAroundY:(float)yRotation scaling:(float)scaleFactor translationInX:(float)xTranslation translationInY:(float)yTranslation;
- (void)runOpenGLBenchmarks;

// Manage molecule rendering state
- (void)handleFinishOfMoleculeRendering:(NSNotification *)note;


// Touch handling
- (float)distanceBetweenTouches:(NSSet *)touches;
- (CGPoint)commonDirectionOfTouches:(NSSet *)touches;

// Interface methods
- (IBAction)switchToTableView;


@end
