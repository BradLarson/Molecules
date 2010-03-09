//
//  SLSMoleculeRootViewController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/30/2008.
//
//  This controller manages a root view into which the 3D view and the molecule table selection views and animated for the neat flipping effect

#import <UIKit/UIKit.h>
#import <sqlite3.h>
#import "SLSMoleculeCustomDownloadViewController.h"

@class SLSMoleculeGLViewController;
@class SLSMolecule;
@class SLSMoleculeTableViewController;

@interface SLSMoleculeRootViewController : UIViewController <MoleculeCustomDownloadDelegate>
{
	SLSMoleculeGLViewController *glViewController;
	UIButton *rotationButton;
	UINavigationController *tableNavigationController;
	SLSMoleculeTableViewController *tableViewController;

	SLSMolecule *bufferedMolecule, *previousMolecule;
	NSMutableArray *molecules;
	
	BOOL toggleViewDisabled;
	
	sqlite3 *database;
}

@property (nonatomic, retain) SLSMoleculeGLViewController *glViewController;
@property (nonatomic, assign) sqlite3 *database;
@property (nonatomic, retain) NSMutableArray *molecules;

// Manage the switching of views
- (void)loadTableViewController;
- (void)toggleView:(NSNotification *)note;

// Passthroughs for managing molecules
- (void)loadInitialMolecule;
- (void)selectedMoleculeDidChange:(NSInteger)newMoleculeIndex;
- (void)cancelMoleculeLoading;
- (void)updateTableListOfMolecules;

// Manage the switching of rotation state
- (void)toggleRotationButton:(NSNotification *)note;


@end

