//
//  SLSMoleculeDownloadViewController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 7/2/2008.
//
//  This controller manages the pop-up modal view for downloading new molecules from the Protein Data Bank

#import <UIKit/UIKit.h>

@interface SLSMoleculeDownloadController : NSObject
{
	NSString *codeForCurrentlyDownloadingProtein, *titleForCurrentlyDownloadingProtein;
	NSMutableData *downloadedFileContents;

	long long downloadFileSize;
	BOOL downloadCancelled;
	NSURLConnection *downloadConnection;	
}

// Initialization and teardown
- (id)initWithPDBCode:(NSString *)pdbCode andTitle:(NSString *)title;

- (BOOL)downloadPDBFile;
- (void)downloadCompleted;
- (void)cancelDownload;

@end