//
//  SLSMoleculeSearchViewController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 7/22/2008.
//
//  This handles the keyword searching functionality of the Protein Data Bank

#import <UIKit/UIKit.h>
#import "SLSMoleculeTableViewController.h"
#import "SLSMoleculeDownloadViewController.h"

@interface SLSMoleculeSearchViewController : UITableViewController <UISearchBarDelegate>
{
	UISearchBar *keywordSearchBar;
	NSMutableArray *searchResultTitles, *searchResultPDBCodes;
	NSMutableData *downloadedFileContents;
	NSURLConnection *searchResultRetrievalConnection, *nextResultsRetrievalConnection;
	NSUInteger currentPageOfResults;
	BOOL searchCancelled, isDownloading;
    NSInteger indexOfDownloadingMolecule;
}

// Performing search
- (BOOL)performSearchWithKeyword:(NSString *)keyword;
- (void)processSearchResultsAppendingNewData:(BOOL)appendData;
- (BOOL)grabNextSetOfSearchResults;

@end
