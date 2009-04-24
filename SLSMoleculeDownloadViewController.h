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
	
	id<MoleculeDownloadDelegate> delegate;

}

@property(nonatomic, assign) id<MoleculeDownloadDelegate> delegate;

- (id)initWithPDBCode:(NSString *)pdbCode andTitle:(NSString *)title;

- (IBAction)showWebPageForMolecule;
- (IBAction)returnToDetailView;
- (IBAction)cancelDownload;

- (IBAction)downloadNewProtein;
- (BOOL)downloadPDBFile;
- (void)enableControls:(BOOL)controlsAreEnabled;
- (void)downloadCompleted;

@end

@protocol MoleculeDownloadDelegate <NSObject>
- (void)moleculeDownloadController:(SLSMoleculeDownloadViewController *)moleculeDownloadViewController didAddMolecule:(NSData *)moleculeData withFilename:(NSString *)filename;
@end
