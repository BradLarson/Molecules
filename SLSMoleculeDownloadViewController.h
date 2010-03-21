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

@protocol MoleculeDownloadDelegate;

@interface SLSMoleculeDownloadViewController : UIViewController <UIWebViewDelegate>
{
	NSString *codeForCurrentlyDownloadingProtein, *titleForCurrentlyDownloadingProtein;
	NSMutableData *downloadedFileContents;

	IBOutlet UIView *pdbDownloadDisplayView, *pdbInformationWebView;

	IBOutlet UILabel *moleculeTitleText, *downloadStatusText;
	IBOutlet UIButton *pdbInformationDisplayButton, *pdbDownloadButton;
	IBOutlet UIProgressView *downloadStatusBar;
	IBOutlet UIActivityIndicatorView *indefiniteDownloadIndicator;
	
	IBOutlet UIWebView *pdbCodeSearchWebView;
	IBOutlet UILabel *webLoadingLabel;
	IBOutlet UIActivityIndicatorView *webLoadingIndicator;
	long long downloadFileSize;
	BOOL downloadCancelled;
	NSURLConnection *downloadConnection;
	
	id<MoleculeDownloadDelegate> delegate;

}

@property(nonatomic, assign) id<MoleculeDownloadDelegate> delegate;
@property(nonatomic, retain) IBOutlet UIView *pdbDownloadDisplayView, *pdbInformationWebView;
@property(nonatomic, retain) IBOutlet UILabel *moleculeTitleText, *downloadStatusText;
@property(nonatomic, retain) IBOutlet UIButton *pdbInformationDisplayButton, *pdbDownloadButton;
@property(nonatomic, retain) IBOutlet UIProgressView *downloadStatusBar;
@property(nonatomic, retain) IBOutlet UIActivityIndicatorView *indefiniteDownloadIndicator;
@property(nonatomic, retain) IBOutlet UIWebView *pdbCodeSearchWebView;
@property(nonatomic, retain) IBOutlet UILabel *webLoadingLabel;
@property(nonatomic, retain) IBOutlet UIActivityIndicatorView *webLoadingIndicator;

// Initialization and teardown
- (id)initWithPDBCode:(NSString *)pdbCode andTitle:(NSString *)title;

- (IBAction)showWebPageForMolecule;
- (IBAction)returnToDetailView;
- (IBAction)cancelDownload;

- (IBAction)downloadNewProtein;
- (BOOL)downloadPDBFile;
- (void)enableControls:(BOOL)controlsAreEnabled;
- (void)downloadCompleted;

@end