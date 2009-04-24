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
	NSMutableArray *searchResultPDBCodes, *searchResultTitles;
	NSMutableDictionary *dictionaryToAssociatePDBCodesAndTitles;
	NSMutableData *downloadedFileContents;
	NSXMLParser *searchResultsParser;
	NSMutableString *currentXMLElementString;
	NSURLConnection *pdbCodeRetrievalConnection, *titleRetrievalConnection;
	BOOL searchCancelled;
}

@property (readwrite, assign) id<MoleculeDownloadDelegate> delegate;

- (void)processSearchResults;
- (BOOL)finishParsingXML;
- (void)finishLoadingTitles;

@end
