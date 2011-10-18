//
//  SLSMoleculeCustomDownloadView.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 11/10/2008.

#import <QuartzCore/QuartzCore.h>
#import "SLSMoleculeCustomDownloadViewController.h"

#import "SLSMolecule.h"
#import "SLSMoleculeAppDelegate.h"

@implementation SLSMoleculeCustomDownloadViewController

#pragma mark -
#pragma mark Initialization and breakdown

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) 
	{
		self.title = NSLocalizedStringFromTable(@"Custom Location", @"Localized", @"");		
		self.navigationItem.rightBarButtonItem = nil;		
    }
    return self;
}



// Implement loadView to create a view hierarchy programmatically.
- (void)loadView 
{
//	UIView *mainView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	UIView *mainView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 240.0f)];
	mainView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
	if ([SLSMoleculeAppDelegate isRunningOniPad])
	{
		mainView.backgroundColor = [UIColor whiteColor];
		self.contentSizeForViewInPopover = CGSizeMake(320.0f, 100.0f);
	}
	else
	{
		mainView.backgroundColor = [UIColor groupTableViewBackgroundColor];

	}
	mainView.autoresizesSubviews = YES;
	self.view = mainView;
	
	UILabel *descriptionLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 20.0f, mainView.bounds.size.width - 40.0f, 60.0f)];
	descriptionLabel.text = NSLocalizedStringFromTable(@"Type or paste in the location of the custom molecule and press Go to begin the download.", @"Localized", @"");
	descriptionLabel.numberOfLines = 3;
	if ([SLSMoleculeAppDelegate isRunningOniPad])
		descriptionLabel.backgroundColor = [UIColor whiteColor];
	else
		descriptionLabel.backgroundColor = [UIColor clearColor];
	[mainView addSubview:descriptionLabel];
	
	urlInput = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, 100.0f, mainView.bounds.size.width - 40.0f, 30.0f)];
	urlInput.placeholder = NSLocalizedStringFromTable(@"Molecule location", @"Localized", nil);
	urlInput.delegate = self;
	urlInput.adjustsFontSizeToFitWidth = YES;
	//		urlInput.font = [UIFont systemFontOfSize:14];
	urlInput.borderStyle = UITextBorderStyleRoundedRect;
	urlInput.keyboardType = UIKeyboardTypeURL;
	urlInput.autocorrectionType = UITextAutocorrectionTypeNo;
	urlInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
	urlInput.returnKeyType = UIReturnKeyGo;
	urlInput.enablesReturnKeyAutomatically = YES;
	
	[mainView addSubview:urlInput];
	[urlInput becomeFirstResponder];
	
	
	
}

/*
// Implement viewDidLoad to do additional setup after loading the view.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	return YES;
    // Return YES for supported orientations
//    return (interfaceOrientation == UIInterfaceOrientationPortrait);
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
												   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
	[alert show];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *url = [request URL];
	if ([SLSMolecule isFiletypeSupportedForFile:[url path]])
	{
//		[self.delegate customURLSelectedForMoleculeDownload:url];
		return NO;
	}
	return YES;
}

#pragma mark -
#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	
	// Either load the url in the web view or start the download process of the new molecule

	NSString *urlString = urlInput.text;
	NSRange locationOfSubstring = [urlString rangeOfString:@"://"];
	if (locationOfSubstring.location == NSNotFound)
		urlString = [NSString stringWithFormat:@"http://%@", urlString];
	
	if ([SLSMolecule isFiletypeSupportedForFile:urlInput.text])
	{
		[urlInput resignFirstResponder];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"CustomURLForMoleculeSelected" object:[NSURL URLWithString:urlString]];
		
		if ([SLSMoleculeAppDelegate isRunningOniPad])
		{
			[self.navigationController popViewControllerAnimated:YES];
		}		
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error in loading custom location", @"Localized", nil) message:NSLocalizedStringFromTable(@"The address does not contain a file of a supported molecule type.", @"Localized", nil)
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
		[alert show];
	}
	
	return YES;
}

#pragma mark -
#pragma mark UIViewController methods

- (void)viewWillDisappear:(BOOL)animated
{
	urlInput.delegate = nil;

	[super viewWillDisappear:animated];
}

@end
