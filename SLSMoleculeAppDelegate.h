//
//  SLSMoleculeAppDelegate.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 5/18/2008.
//
//  This is the base application delegate, used for handling launch, termination, and memory-related delegate methods

#import <UIKit/UIKit.h>
#import <sqlite3.h>
#import "SLSMoleculeCustomDownloadViewController.h"

@class SLSMoleculeRootViewController;


@interface SLSMoleculeAppDelegate : NSObject <UIApplicationDelegate> 
{
	IBOutlet UIWindow *window;
	IBOutlet SLSMoleculeRootViewController *rootViewController;

	NSMutableData *downloadedFileContents;
	NSString *nameOfDownloadedMolecule;
	BOOL downloadCancelled;
	NSLock *initialDatabaseLoadLock;
	BOOL isGzipCompressionUsedOnDownload, isHandlingCustomURLMoleculeDownload;
	
	// SQLite database of all molecules
	sqlite3 *database;
	NSMutableArray *molecules;
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) SLSMoleculeRootViewController *rootViewController;

// Database access
- (BOOL)createEditableCopyOfDatabaseIfNeeded; 
- (void)connectToDatabase;
- (void)disconnectFromDatabase;
- (void)loadAllMoleculesFromDatabase;
- (void)loadInitialMoleculesFromDisk;
- (void)loadMissingMoleculesIntoDatabase;

// Status update methods
- (void)showStatusIndicator;
- (void)showDownloadIndicator;
- (void)updateStatusIndicator;
- (void)hideStatusIndicator;

// Custom molecule download methods
- (void)downloadCompleted;
- (void)saveMoleculeWithData:(NSData *)moleculeData toFilename:(NSString *)filename;

@end

