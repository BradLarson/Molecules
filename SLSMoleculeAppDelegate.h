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
	UIWindow *window;
	SLSMoleculeRootViewController *rootViewController;
	UIViewController *splitViewController;
	
	NSURLConnection *downloadConnection;
	NSMutableData *downloadedFileContents;
	NSString *nameOfDownloadedMolecule;
	BOOL downloadCancelled;
	NSLock *initialDatabaseLoadLock;
	BOOL isGzipCompressionUsedOnDownload, isHandlingCustomURLMoleculeDownload;
	
	// SQLite database of all molecules
	sqlite3 *database;
	NSMutableArray *molecules;
}

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) SLSMoleculeRootViewController *rootViewController;

// Device-specific interface control
+ (BOOL)isRunningOniPad;

// Database access
- (NSString *)cachesDirectory;
- (NSString *)applicationSupportDirectory;
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
- (BOOL)handleCustomURLScheme:(NSURL *)url;
- (void)downloadCompleted;
- (void)saveMoleculeWithData:(NSData *)moleculeData toFilename:(NSString *)filename;

@end

