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

@interface SLSMoleculeSearchViewController : UITableViewController <MoleculeDownloadDelegate, UISearchBarDelegate>
{
	id<MoleculeDownloadDelegate> delegate;
	UISearchBar *keywordSearchBar;
	NSMutableArray *searchResultTitles, *searchResultPDBCodes;
	NSMutableData *downloadedFileContents;
	NSURLConnection *searchResultRetrievalConnection, *nextResultsRetrievalConnection;
	NSUInteger currentPageOfResults;
	BOOL searchCancelled;
}

@property (readwrite, assign) id<MoleculeDownloadDelegate> delegate;

// Performing search
- (BOOL)performSearchWithKeyword:(NSString *)keyword;
- (void)processSearchResultsAppendingNewData:(BOOL)appendData;
- (BOOL)grabNextSetOfSearchResults;

@end
