//
//  SLSMoleculeDownloadViewController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 7/2/2008.
//
//  This controller manages the pop-up modal view for downloading new molecules from the Protein Data Bank

#import "SLSMoleculeDownloadViewController.h"
#import "SLSMoleculeAppDelegate.h"

@implementation SLSMoleculeDownloadViewController

- (id)initWithPDBCode:(NSString *)pdbCode andTitle:(NSString *)title;
{
	if (self = [super initWithNibName:@"SLSMoleculeDownloadView" bundle:nil]) 
	{
		// Initialization code
		downloadedFileContents = nil;
		downloadCancelled = NO;
		
		codeForCurrentlyDownloadingProtein = [pdbCode copy];
		titleForCurrentlyDownloadingProtein = [title copy];
		self.title = codeForCurrentlyDownloadingProtein;
		
		if ([SLSMoleculeAppDelegate isRunningOniPad])
		{
			self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
		}
	}
	return self;
}


- (void)dealloc;
{
	self.pdbDownloadDisplayView = nil;
	self.pdbInformationWebView = nil;
	self.moleculeTitleText = nil;
	self.downloadStatusText = nil;
	self.pdbInformationDisplayButton = nil;
	self.pdbDownloadButton = nil;
	self.downloadStatusBar = nil;
	self.indefiniteDownloadIndicator = nil;
	self.pdbCodeSearchWebView = nil;
	self.webLoadingLabel = nil;
	self.webLoadingIndicator = nil;
	
	[self cancelDownload];
	[codeForCurrentlyDownloadingProtein release];
	[titleForCurrentlyDownloadingProtein release];
	[pdbDownloadButton release];
	[super dealloc];

}
/*
 Implement loadView if you want to create a view hierarchy programmatically
- (void)loadView {
}
 */

- (void)viewDidLoad 
{
	[self.view addSubview:pdbDownloadDisplayView];
	[indefiniteDownloadIndicator stopAnimating];
	indefiniteDownloadIndicator.hidden = YES;
		
	[pdbDownloadDisplayView setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
	
	moleculeTitleText.text = titleForCurrentlyDownloadingProtein;
	
	// Set up the green download button
	pdbDownloadButton = [[UIButton alloc] initWithFrame:CGRectMake(36, 212, 247, 37)];
	
	pdbDownloadButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	pdbDownloadButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
	
	[pdbDownloadButton setTitle:NSLocalizedStringFromTable(@"Download", @"Localized", nil) forState:UIControlStateNormal];	
	[pdbDownloadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	//[pdbDownloadButton setFont:[UIFont boldSystemFontOfSize:14.0]];
	
	UIImage *newImage = [[UIImage imageNamed:@"greenButton.png"] stretchableImageWithLeftCapWidth:12.0f topCapHeight:0.0f];
	[pdbDownloadButton setBackgroundImage:newImage forState:UIControlStateNormal];
		
	[pdbDownloadButton addTarget:self action:@selector(downloadNewProtein) forControlEvents:UIControlEventTouchDown];
	
    // in case the parent view draws with a custom color or gradient, use a transparent color
	pdbDownloadButton.backgroundColor = [UIColor clearColor];
	[pdbDownloadDisplayView addSubview:pdbDownloadButton];
	
//	pdbInformationWebView. = codeForCurrentlyDownloadingProtein;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	return YES;
	// Return YES for supported orientations
//	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)didReceiveMemoryWarning 
{
}

#pragma mark -
#pragma mark View control methods

- (IBAction)showWebPageForMolecule;
{
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:1];
	[UIView setAnimationTransition:UIViewAnimationTransitionCurlUp forView:self.view cache:YES];
	
	[pdbDownloadDisplayView removeFromSuperview];
	[self.view addSubview:pdbInformationWebView];
	pdbCodeSearchWebView.delegate = self;
	
	UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Done", @"Localized", nil) style:UIBarButtonItemStylePlain target:self action:@selector(returnToDetailView)];
	self.navigationItem.rightBarButtonItem = cancelButtonItem;
	[cancelButtonItem release];
	
	[UIView commitAnimations];
	
	// Only send the user to the Protein Data Bank page if it hasn't already been loaded
	if ([pdbCodeSearchWebView request] == nil)
	{
		NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.rcsb.org/pdb/explore/explore.do?structureId=%@", codeForCurrentlyDownloadingProtein]]
												  cachePolicy:NSURLRequestUseProtocolCachePolicy
											  timeoutInterval:60.0];
		[pdbCodeSearchWebView loadRequest:theRequest];
	}
}

- (IBAction)returnToDetailView;
{
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:1];
	[UIView setAnimationTransition:UIViewAnimationTransitionCurlDown forView:self.view cache:YES];
	
	self.navigationItem.rightBarButtonItem = nil;
	pdbCodeSearchWebView.delegate = nil;

	[pdbInformationWebView removeFromSuperview];
	[self.view addSubview:pdbDownloadDisplayView];
	
	[UIView commitAnimations];
}

- (IBAction)cancelDownload;
{
	downloadCancelled = YES;
	
	UIImage *newImage = [[UIImage imageNamed:@"greenButton.png"] stretchableImageWithLeftCapWidth:12.0 topCapHeight:0.0];
	[pdbDownloadButton setBackgroundImage:newImage forState:UIControlStateNormal];
	[pdbDownloadButton removeTarget:self action:@selector(cancelDownload) forControlEvents:UIControlEventTouchDown];	
	[pdbDownloadButton addTarget:self action:@selector(downloadNewProtein) forControlEvents:UIControlEventTouchDown];
	[pdbDownloadButton setTitle:NSLocalizedStringFromTable(@"Download", @"Localized", nil) forState:UIControlStateNormal];	
	
	//[self.delegate moleculeDownloadController:self didAddMolecule:nil withCode:nil];
}

#pragma mark -
#pragma mark Protein downloading

- (IBAction)downloadNewProtein;
{
	// Check if you already have a protein by that name
	// TODO: Put this check in the init method to grey out download button
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];

	if ([[NSFileManager defaultManager] fileExistsAtPath:[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.pdb.gz", codeForCurrentlyDownloadingProtein]]])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"File already exists", @"Localized", nil) message:NSLocalizedStringFromTable(@"The molecule with this PDB code has already been downloaded", @"Localized", nil)
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
		alert.backgroundColor = [UIColor redColor];
		[alert show];
		[alert release];
		return;
	}
	
	if (![self downloadPDBFile])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Connection failed", @"Localized", nil) message:NSLocalizedStringFromTable(@"Could not connect to the Protein Data Bank", @"Localized", nil)
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
		[alert show];
		[alert release];
		return;
	}
}

- (BOOL)downloadPDBFile;
{
	// Switch the mode of the download button to cancel
	UIImage *newImage = [[UIImage imageNamed:@"redButton.png"] stretchableImageWithLeftCapWidth:12.0 topCapHeight:0.0];
	[pdbDownloadButton setBackgroundImage:newImage forState:UIControlStateNormal];
	[pdbDownloadButton removeTarget:self action:@selector(downloadNewProtein) forControlEvents:UIControlEventTouchDown];	
	[pdbDownloadButton addTarget:self action:@selector(cancelDownload) forControlEvents:UIControlEventTouchDown];
	[pdbDownloadButton setTitle:NSLocalizedStringFromTable(@"Cancel download", @"Localized", nil) forState:UIControlStateNormal];	
	
	downloadStatusBar.progress = 0.0f;
	[self enableControls:NO];
	[indefiniteDownloadIndicator startAnimating];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	downloadStatusText.hidden = NO;
	downloadStatusText.text = NSLocalizedStringFromTable(@"Connecting...", @"Localized", nil);
		
//	NSString *locationOfRemotePDBFile = [NSString stringWithFormat:@"http://www.sunsetlakesoftware.com/sites/default/files/%@.pdb.gz", pdbCode];
	NSString *locationOfRemotePDBFile = [NSString stringWithFormat:@"http://www.rcsb.org/pdb/files/%@.pdb.gz", codeForCurrentlyDownloadingProtein];

	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:locationOfRemotePDBFile]
											  cachePolicy:NSURLRequestUseProtocolCachePolicy
										  timeoutInterval:60.0];
	downloadConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	if (downloadConnection) 
	{
		// Create the NSMutableData that will hold
		// the received data
		// receivedData is declared as a method instance elsewhere
		downloadedFileContents = [[NSMutableData data] retain];
	} 
	else 
	{
		// inform the user that the download could not be made
		return NO;
	}
	return YES;
}

- (void)enableControls:(BOOL)controlsAreEnabled;
{
	pdbInformationDisplayButton.enabled = controlsAreEnabled;
//	pdbDownloadButton.enabled = controlsAreEnabled;	
}

- (void)downloadCompleted;
{
	[downloadConnection release];
	downloadConnection = nil;
	

	[downloadedFileContents release];
	downloadedFileContents = nil;
	downloadStatusBar.hidden = YES;
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	[indefiniteDownloadIndicator stopAnimating];
	downloadStatusText.hidden = YES;

	[self enableControls:YES];
}



#pragma mark -
#pragma mark URL connection delegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Connection failed", @"Localized", nil) message:NSLocalizedStringFromTable(@"Could not connect to the Protein Data Bank", @"Localized", nil)
												   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
	[alert show];
	[alert release];
	
	[self downloadCompleted];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
{
	// Concatenate the new data with the existing data to build up the downloaded file
	// Update the status of the download
	
	if (downloadCancelled)
	{
		[connection cancel];
		[self downloadCompleted];
		downloadCancelled = NO;
		return;
	}
	[downloadedFileContents appendData:data];
	downloadStatusBar.progress = (float)[downloadedFileContents length] / (float)downloadFileSize;
	downloadStatusText.text = NSLocalizedStringFromTable(@"Downloading", @"Localized", nil);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
{
	downloadFileSize = [response expectedContentLength];
	
	// Stop the spinning wheel and start the status bar for download
	if ([response textEncodingName] != nil)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Could not find file", @"Localized", nil) message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"No protein with the code %@ exists in the data bank", @"Localized", nil), codeForCurrentlyDownloadingProtein]
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
		[alert show];
		[alert release];		
		[connection cancel];
		[self downloadCompleted];
		return;
	}
	
	if (downloadFileSize > 0)
	{
		downloadStatusBar.hidden = NO;
		[indefiniteDownloadIndicator stopAnimating];
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	}
	downloadStatusText.text = NSLocalizedStringFromTable(@"Connected", @"Localized", nil);

	// TODO: Deal with a 404 error by checking filetype header
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
{
	downloadStatusText.text = NSLocalizedStringFromTable(@"Processing...", @"Localized", nil);

	// Close off the file and write it to disk	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *filename = [NSString stringWithFormat:@"%@.pdb.gz", codeForCurrentlyDownloadingProtein];
	
	NSError *error = nil;
	if (![downloadedFileContents writeToFile:[documentsDirectory stringByAppendingPathComponent:filename] options:NSAtomicWrite error:&error])
	{
		// TODO: Do some error handling here
		return;
	}
	
	// Notify about the addition of the new molecule
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MoleculeDidFinishDownloading" object:filename];
	
	if ([SLSMoleculeAppDelegate isRunningOniPad])
	{
		[self.navigationController popViewControllerAnimated:YES];
	}
	
	[self downloadCompleted];	
}

#pragma mark -
#pragma mark Webview delegate methods

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	webLoadingLabel.hidden = NO;
	[webLoadingIndicator startAnimating];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	//	progView.hidden = NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	webLoadingLabel.hidden = YES;
	[webLoadingIndicator stopAnimating];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	// TODO: Present error dialog to user explaining what's going on
	[webLoadingIndicator stopAnimating];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];	
}

#pragma mark -
#pragma mark UIViewController methods

- (void)viewWillDisappear:(BOOL)animated
{
	pdbCodeSearchWebView.delegate = nil;
	
	[super viewWillDisappear:animated];
}

#pragma mark -
#pragma mark Accessors

@synthesize delegate;
@synthesize pdbDownloadDisplayView, pdbInformationWebView;
@synthesize moleculeTitleText, downloadStatusText;
@synthesize pdbInformationDisplayButton, pdbDownloadButton;
@synthesize downloadStatusBar;
@synthesize indefiniteDownloadIndicator;
@synthesize pdbCodeSearchWebView;
@synthesize webLoadingLabel;
@synthesize webLoadingIndicator;


@end
