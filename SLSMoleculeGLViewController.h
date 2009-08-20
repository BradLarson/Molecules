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

@class SLSMolecule;

@interface SLSMoleculeGLViewController : UIViewController 
{
	UIActivityIndicatorView *scanningActivityIndicator;
	UIProgressView *renderingProgressIndicator;
	UILabel *renderingActivityLabel;	
}

- (void)selectedMoleculeDidChange:(SLSMolecule *)newMolecule;

// Interface updates
- (void)showScanningIndicator:(NSNotification *)note;
- (void)updateScanningIndicator:(NSNotification *)note;
- (void)hideScanningIndicator:(NSNotification *)note;
- (void)showRenderingIndicator:(NSNotification *)note;
- (void)updateRenderingIndicator:(NSNotification *)note;
- (void)hideRenderingIndicator:(NSNotification *)note;

@end
