//
//  SLSMoleculeGLViewController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/30/2008.
//
//  A controller for managing the OpenGL view of the molecule.

#import <UIKit/UIKit.h>
#import <OpenGLES/ES1/gl.h>
#import <QuartzCore/QuartzCore.h>

@class SLSMolecule;
@class SLSOpenGLESRenderer;

@interface SLSMoleculeGLViewController : UIViewController <UIActionSheetDelegate>
{	
	// User interface elements
	UIActivityIndicatorView *scanningActivityIndicator;
	UIProgressView *renderingProgressIndicator;
	UILabel *renderingActivityLabel;
	UIActionSheet *visualizationActionSheet;

    SLSOpenGLESRenderer *openGLESRenderer;
    
	SLSMolecule *moleculeToDisplay;
	BOOL isAutorotating;
	CADisplayLink *displayLink;
	CFTimeInterval previousTimestamp;
	BOOL shouldResizeDisplay;

	NSUInteger stepsSinceLastRotation;

	// Touch-handling 
	float startingTouchDistance, previousScale;
	float instantObjectScale, instantXRotation, instantYRotation, instantXTranslation, instantYTranslation, instantZTranslation;
	CGPoint lastMovementPosition, previousDirectionOfPanning;
	BOOL twoFingersAreMoving, pinchGestureUnderway;
}

@property (readwrite, strong, nonatomic) UIActionSheet *visualizationActionSheet;
@property (readwrite, strong, nonatomic) SLSMolecule *moleculeToDisplay;
@property (readwrite, strong, nonatomic) CADisplayLink *displayLink;

// Display indicator control
- (void)showScanningIndicator:(NSNotification *)note;
- (void)updateScanningIndicator:(NSNotification *)note;
- (void)hideScanningIndicator:(NSNotification *)note;
- (void)showRenderingIndicator:(NSNotification *)note;
- (void)updateRenderingIndicator:(NSNotification *)note;
- (void)hideRenderingIndicator:(NSNotification *)note;

// Autorotation of molecule
- (void)startOrStopAutorotation:(id)sender;
- (void)handleAutorotationTimer;

// OpenGL molecule rendering
- (void)resizeView;
- (void)runOpenGLBenchmarks;
- (void)updateSizeOfGLView:(NSNotification *)note;
- (void)handleStartOfAutorotation;
- (void)handleEndOfAutorotation;

// Manage molecule rendering state
- (void)handleFinishOfMoleculeRendering:(NSNotification *)note;
- (UIActionSheet *)actionSheetForVisualizationState;

// Touch handling
- (float)distanceBetweenTouches:(NSSet *)touches;
- (CGPoint)commonDirectionOfTouches:(NSSet *)touches;
- (void)handleTouchesEnding:(NSSet *)touches withEvent:(UIEvent *)event;

// Interface methods
- (IBAction)switchToTableView;


@end
