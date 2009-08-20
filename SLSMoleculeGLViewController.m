//
//  SLSMoleculeGLViewController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/30/2008.
//
//  A barebones controller for managing the OpenGL view of the molecule.  It's pretty sparse, as some of the methods in the view really belong here.

#import "SLSMoleculeGLViewController.h"
#import "SLSMoleculeGLView.h"
#import "SLSMolecule.h"

@implementation SLSMoleculeGLViewController

#pragma mark -
#pragma mark Initialization and teardown

- (void)dealloc 
{
	[super dealloc];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) 
	{
		// Set up an observer that catches the molecule update notifications and shows and updates the rendering indicator
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(showRenderingIndicator:) name:@"MoleculeRenderingStarted" object:nil];
		[nc addObserver:self selector:@selector(updateRenderingIndicator:) name:@"MoleculeRenderingUpdate" object:nil];
		[nc addObserver:self selector:@selector(hideRenderingIndicator:) name:@"MoleculeRenderingEnded" object:nil];
		
		[nc addObserver:self selector:@selector(showScanningIndicator:) name:@"FileLoadingStarted" object:nil];
		[nc addObserver:self selector:@selector(updateScanningIndicator:) name:@"FileLoadingUpdate" object:nil];
		[nc addObserver:self selector:@selector(hideScanningIndicator:) name:@"FileLoadingEnded" object:nil];
	}
	return self;
}

- (void)viewDidLoad 
{
	SLSMoleculeGLView *glView = [[SLSMoleculeGLView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	UIButton *infoButton = [[UIButton buttonWithType:UIButtonTypeInfoLight] retain];
	infoButton.frame = CGRectMake(320 - 70, 460 - 70, 70, 70);
	[infoButton addTarget:glView action:@selector(switchToTableView) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
	[glView addSubview:infoButton];
	[infoButton release];
	
	self.view = glView;
	
	[glView release];
}

#pragma mark -
#pragma mark Interface updates

- (void)showScanningIndicator:(NSNotification *)note;
{
	scanningActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	scanningActivityIndicator.frame = CGRectMake(142.0f, 212.0f, 37.0f, 37.0f);
	
	renderingActivityLabel = [[UILabel alloc] initWithFrame:CGRectMake(51.0f, 176.0f, 219.0f, 21.0f)];
	renderingActivityLabel.font = [UIFont systemFontOfSize:17.0f];
	renderingActivityLabel.text = [note object];
	renderingActivityLabel.textAlignment = UITextAlignmentCenter;
	renderingActivityLabel.backgroundColor = [UIColor clearColor];
	renderingActivityLabel.textColor = [UIColor whiteColor];
	
	[self.view addSubview:scanningActivityIndicator];
	[self.view addSubview:renderingActivityLabel];
}

- (void)updateScanningIndicator:(NSNotification *)note;
{
	
}

- (void)hideScanningIndicator:(NSNotification *)note;
{
	[renderingActivityLabel removeFromSuperview];
	[renderingActivityLabel release];
	renderingActivityLabel = nil;
	
	[scanningActivityIndicator removeFromSuperview];
	[scanningActivityIndicator release];
	scanningActivityIndicator = nil;
}

- (void)showRenderingIndicator:(NSNotification *)note;
{
	renderingProgressIndicator = [[UIProgressView alloc] initWithFrame:CGRectMake(85.0f, 226.0f, 150.0f, 9.0f)];
	[renderingProgressIndicator setProgress:0.0f];
	
	renderingActivityLabel = [[UILabel alloc] initWithFrame:CGRectMake(51.0f, 176.0f, 219.0f, 21.0f)];
	renderingActivityLabel.font = [UIFont systemFontOfSize:17.0f];
	renderingActivityLabel.text = NSLocalizedStringFromTable(@"Rendering...", @"Localized", nil);
	renderingActivityLabel.textAlignment = UITextAlignmentCenter;
	renderingActivityLabel.backgroundColor = [UIColor clearColor];
	renderingActivityLabel.textColor = [UIColor whiteColor];

	[(SLSMoleculeGLView *)self.view clearScreen];
	[renderingProgressIndicator setProgress:0.0];
	[self.view addSubview:renderingProgressIndicator];
	[self.view addSubview:renderingActivityLabel];
}

- (void)updateRenderingIndicator:(NSNotification *)note;
{
	float percentComplete = [(NSNumber *)[note object] floatValue];
	
	if ((percentComplete - renderingProgressIndicator.progress) > 0.01f)
	{
		renderingProgressIndicator.progress = percentComplete;
	}
}

- (void)hideRenderingIndicator:(NSNotification *)note;
{
	[renderingActivityLabel removeFromSuperview];
	[renderingProgressIndicator removeFromSuperview];

	[renderingActivityLabel release];
	renderingActivityLabel = nil;
	
	[renderingProgressIndicator release];
	renderingProgressIndicator = nil;
}


#pragma mark -
#pragma mark UIViewController methods

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)didReceiveMemoryWarning 
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}

- (void)selectedMoleculeDidChange:(SLSMolecule *)newMolecule;
{
	[(SLSMoleculeGLView *)[self view] setMoleculeToDisplay:newMolecule];
}

@end
