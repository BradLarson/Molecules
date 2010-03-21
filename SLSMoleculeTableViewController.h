//
//  SLSMoleculeTableViewController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/30/2008.
//
//  This controller manages the root table of molecules that are stored on the device

#import <UIKit/UIKit.h>

#import "SLSMoleculeRootViewController.h"
#import "SLSMoleculeSearchViewController.h"
#import "SLSMoleculeDownloadViewController.h"
#import "SLSMoleculeDetailViewController.h"
#import "SLSMoleculeCustomDownloadViewController.h"


@interface SLSMoleculeTableViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate>
{
	SLSMoleculeDownloadViewController *downloadController;

	NSMutableArray *molecules;
	SLSMoleculeRootViewController *delegate;
	NSInteger selectedIndex;
	UIColor *tableTextColor;
	
	sqlite3 *database;
}

@property(readwrite,retain) SLSMoleculeDownloadViewController *downloadController;
@property(readwrite,assign) SLSMoleculeRootViewController *delegate;
@property(readwrite,assign) sqlite3 *database;
@property(readwrite,retain) NSMutableArray *molecules;
@property(readwrite) NSInteger selectedIndex;


- (id)initWithStyle:(UITableViewStyle)style initialSelectedMoleculeIndex:(NSInteger)initialSelectedMoleculeIndex;

- (IBAction)displayMoleculeDownloadView;
- (IBAction)switchBackToGLView;

- (void)moleculeDidFinishDownloading:(NSNotification *)note;

@end
