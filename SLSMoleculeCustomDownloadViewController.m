//
//  SLSMoleculeCustomDownloadView.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 11/10/2008.

#import "SLSMoleculeCustomDownloadViewController.h"
#import "SLSMolecule.h"
#import <QuartzCore/QuartzCore.h>

@implementation SLSMoleculeCustomDownloadViewController

#pragma mark -
#pragma mark Initialization and breakdown

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) 
	{
        // Custom initialization
		self.view.frame = [[UIScreen mainScreen] applicationFrame];
		self.view.autoresizesSubviews = YES;
		
		urlInput = [[UITextField alloc] initWithFrame:CGRectMake(0.0f, 40.0f, 200.0f, 30.0f)];
		urlInput.placeholder = NSLocalizedStringFromTable(@"Molecule location", @"Localized", nil);
		urlInput.delegate = self;
		urlInput.adjustsFontSizeToFitWidth = YES;
		urlInput.font = [UIFont systemFontOfSize:14];
		urlInput.borderStyle = UITextBorderStyleRoundedRect;
		urlInput.keyboardType = UIKeyboardTypeURL;
		urlInput.autocorrectionType = UITextAutocorrectionTypeNo;
		urlInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
		urlInput.returnKeyType = UIReturnKeyGo;
		urlInput.enablesReturnKeyAutomatically = YES;
		
		self.navigationItem.titleView = urlInput;
		
		self.navigationItem.rightBarButtonItem = nil;
		
		webView = [[UIWebView alloc] initWithFrame:self.view.frame];
		webView.delegate = self;
		webView.scalesPageToFit = YES;
		self.view = webView;
    }
    return self;
}

- (void)dealloc 
{
	[webView release];
	[urlInput release];
    [super dealloc];
}


/*
// Implement loadView to create a view hierarchy programmatically.
- (void)loadView {
}
*/

/*
// Implement viewDidLoad to do additional setup after loading the view.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)didReceiveMemoryWarning 
{
}



#pragma mark -
#pragma mark Webview delegate methods

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)thewebView
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error in loading custom location", @"Localized", nil) message:NSLocalizedStringFromTable(@"The address could not be reached", @"Localized", nil)
												   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
	[alert show];
	[alert release];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *url = [request URL];
	if ([SLSMolecule isFiletypeSupportedForFile:[url path]])
	{
		[self.delegate customURLSelectedForMoleculeDownload:url];
		return NO;
	}
	return YES;
}

#pragma mark -
#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[urlInput resignFirstResponder];
	
	// Either load the url in the web view or start the download process of the new molecule

	NSString *urlString = urlInput.text;
	NSRange locationOfSubstring = [urlString rangeOfString:@"://"];
	if (locationOfSubstring.location == NSNotFound)
		urlString = [NSString stringWithFormat:@"http://%@", urlString];
	
	if ([SLSMolecule isFiletypeSupportedForFile:urlInput.text])
	{
		[self.delegate customURLSelectedForMoleculeDownload:[NSURL URLWithString:urlString]];
	}
	else
	{
		// Check to make sure that the urlInput has http:// at the beginning
		NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]
												  cachePolicy:NSURLRequestUseProtocolCachePolicy
											  timeoutInterval:60.0];
		[webView loadRequest:theRequest];
		
	}
	
	return YES;
}

#pragma mark -
#pragma mark Accessors

@synthesize delegate;

@end
