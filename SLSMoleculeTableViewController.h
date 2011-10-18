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
#import <QuartzCore/QuartzCore.h>

#import "SLSMoleculeRootViewController.h"
#import "SLSMoleculeSearchViewController.h"
#import "SLSMoleculeDownloadController.h"
#import "SLSMoleculeDetailViewController.h"
#import "SLSMoleculeCustomDownloadViewController.h"


@interface SLSMoleculeTableViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate>
{
	NSMutableArray *molecules;
	SLSMoleculeRootViewController *__unsafe_unretained delegate;
	NSInteger selectedIndex;
	UIColor *tableTextColor;
	
	sqlite3 *database;
}

@property(readwrite,unsafe_unretained) SLSMoleculeRootViewController *delegate;
@property(readwrite,assign) sqlite3 *database;
@property(readwrite,strong) NSMutableArray *molecules;
@property(readwrite) NSInteger selectedIndex;

// Initialization and teardown
- (id)initWithStyle:(UITableViewStyle)style initialSelectedMoleculeIndex:(NSInteger)initialSelectedMoleculeIndex;

// Table customization
+ (CAGradientLayer *)glowGradientForSize:(CGSize)gradientSize;
+ (CAGradientLayer *)shadowGradientForSize:(CGSize)gradientSize;

- (IBAction)displayMoleculeDownloadView;
- (IBAction)switchBackToGLView;

- (void)moleculeDidFinishDownloading:(NSNotification *)note;

@end
