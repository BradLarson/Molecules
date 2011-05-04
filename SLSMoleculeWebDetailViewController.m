//
//  SLSMoleculeWebDetailViewController.m
//  Molecules
//
//  Created by Brad Larson on 4/30/2011.
//  Copyright 2011 Sunset Lake Software LLC. All rights reserved.
//

#import "SLSMoleculeWebDetailViewController.h"


@implementation SLSMoleculeWebDetailViewController

- (id)initWithURL:(NSURL *)moleculeWebPageURL;
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) 
    {
        self.moleculeDetailWebPageURL = moleculeWebPageURL;
    }
    return self;
}

- (void)loadView 
{	
	webDetailView = [[UIWebView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 480.0f)];
	webDetailView.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
    webDetailView.scalesPageToFit = YES;
    
	webDetailView.delegate = self;
	self.view = webDetailView;
	self.view.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
    
	self.title = @"Molecule Details";
    
    //	UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(closeHelpView)];
    //	backButtonItem.layer.transform = CATransform3DMakeScale(-1.0f, 1.0f, 1.0f);
	UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Back", @"Localized", nil) style:UIBarButtonItemStylePlain target:self action:@selector(goBackInWebView)];
	backButtonItem.enabled = NO;
	self.navigationItem.rightBarButtonItem = backButtonItem;
	[backButtonItem release];	
        
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:moleculeDetailWebPageURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    [webDetailView loadRequest:theRequest];
    
    loadingActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    CGSize indicatorSize = loadingActivityIndicator.frame.size;
	loadingActivityIndicator.frame = CGRectMake(round(webDetailView.frame.size.width / 2.0f - indicatorSize.width / 2.0f), round(webDetailView.frame.size.height / 2.0f + indicatorSize.height / 2.0f), indicatorSize.width, indicatorSize.height);
    [webDetailView addSubview:loadingActivityIndicator];
	loadingActivityIndicator.hidesWhenStopped = YES;
	[loadingActivityIndicator startAnimating];
}

- (void)dealloc 
{
	webDetailView.delegate = nil;
	[webDetailView release];
    
    [loadingActivityIndicator removeFromSuperview];
    [loadingActivityIndicator release];
    loadingActivityIndicator = nil;

    [moleculeDetailWebPageURL release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
}
*/

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
}
*/

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -
#pragma mark Web navigation

- (void)goBackInWebView;
{	
	[webDetailView goBack];
}


#pragma mark -
#pragma mark UIWebViewDelegate methods

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [loadingActivityIndicator removeFromSuperview];
    [loadingActivityIndicator release];
    loadingActivityIndicator = nil;
    
	if (![webDetailView canGoBack])
    {
		self.navigationItem.rightBarButtonItem.enabled = NO;
    }
	else
    {
		self.navigationItem.rightBarButtonItem.enabled = YES;	
    }
}

#pragma mark -
#pragma mark Accessors

@synthesize moleculeDetailWebPageURL;

@end
