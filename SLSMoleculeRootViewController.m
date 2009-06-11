//
//  SLSMoleculeRootViewController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/30/2008.
//
//  This controller manages a root view into which the 3D view and the molecule table selection views and animated for the neat flipping effect

#import "SLSMoleculeRootViewController.h"
#import "SLSMoleculeTableViewController.h"
#import "SLSMoleculeGLViewController.h"
#import "SLSMoleculeGLView.h"
#import "SLSMolecule.h"


@implementation SLSMoleculeRootViewController

#pragma mark -
#pragma mark Initialiation and breakdown

- (void)dealloc 
{
	[tableViewController release];
	[glViewController release];
	[tableNavigationController release];
	[super dealloc];
}

- (void)viewDidLoad 
{
	// Set up an observer that catches the molecule update notifications and shows and updates the rendering indicator
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(showRenderingIndicator:) name:@"MoleculeRenderingStarted" object:nil];
	[nc addObserver:self selector:@selector(updateRenderingIndicator:) name:@"MoleculeRenderingUpdate" object:nil];
	[nc addObserver:self selector:@selector(hideRenderingIndicator:) name:@"MoleculeRenderingEnded" object:nil];

	[nc addObserver:self selector:@selector(showScanningIndicator:) name:@"FileLoadingStarted" object:nil];
	[nc addObserver:self selector:@selector(updateScanningIndicator:) name:@"FileLoadingUpdate" object:nil];
	[nc addObserver:self selector:@selector(hideScanningIndicator:) name:@"FileLoadingEnded" object:nil];
	
	
	toggleViewDisabled = NO;

	SLSMoleculeGLViewController *viewController = [[SLSMoleculeGLViewController alloc] initWithNibName:@"SLSMoleculeGLView" bundle:nil];
	self.glViewController = viewController;
	[viewController release];
	
	[self.view addSubview:glViewController.view];
	[(SLSMoleculeGLView *)glViewController.view setDelegate:self];

	[renderingProgressIndicator setProgress:0.0f];
}


- (void)loadTableViewController 
{	
	bufferedMolecule = nil;
    tableNavigationController = [[UINavigationController alloc] init];
	NSInteger indexOfInitialMolecule = [[NSUserDefaults standardUserDefaults] integerForKey:@"indexOfLastSelectedMolecule"];
	if (indexOfInitialMolecule >= [molecules count])
		indexOfInitialMolecule = 0;
    tableViewController = [[SLSMoleculeTableViewController alloc] initWithStyle:UITableViewStylePlain initialSelectedMoleculeIndex:indexOfInitialMolecule];
	tableViewController.database = database;
	tableViewController.molecules = molecules;
    [tableNavigationController pushViewController:tableViewController animated:NO];
	tableViewController.delegate = self;

	// Need to correct the view rectangle of the navigation view to correct for the status bar gap
	UIView *tableView = tableNavigationController.view;
	CGRect tableFrame = tableView.frame;
	tableFrame.origin.y -= 20;
	tableView.frame = tableFrame;
	toggleViewDisabled = NO;
}

#pragma mark -
#pragma mark Interface updates

- (void)showScanningIndicator:(NSNotification *)note;
{
	renderingActivityLabel.text = [note object];
	SLSMoleculeGLView *glView = (SLSMoleculeGLView *)glViewController.view;
	[self.view insertSubview:scanningActivityIndicator aboveSubview:glView];
	[self.view insertSubview:renderingActivityLabel aboveSubview:glView];
}

- (void)updateScanningIndicator:(NSNotification *)note;
{
	
}

- (void)hideScanningIndicator:(NSNotification *)note;
{
	[renderingActivityLabel removeFromSuperview];
	[scanningActivityIndicator removeFromSuperview];	
}

- (void)showRenderingIndicator:(NSNotification *)note;
{
	renderingActivityLabel.text = NSLocalizedStringFromTable(@"Rendering...", @"Localized", nil);
	SLSMoleculeGLView *glView = (SLSMoleculeGLView *)glViewController.view;
	[glView clearScreen];
	[renderingProgressIndicator setProgress:0.0];
	[self.view insertSubview:renderingProgressIndicator aboveSubview:glView];
	[self.view insertSubview:renderingActivityLabel aboveSubview:glView];
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
}

- (IBAction)toggleView 
{	
	if (molecules == nil)
		return;
	
	if (tableNavigationController == nil) 
	{
		[self loadTableViewController];
	}
	
	UIView *tableView = tableNavigationController.view;
	SLSMoleculeGLView *glView = (SLSMoleculeGLView *)glViewController.view;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:1];
	[UIView setAnimationTransition:([glView superview] ? UIViewAnimationTransitionFlipFromRight : UIViewAnimationTransitionFlipFromLeft) forView:self.view cache:YES];
	
	if ([glView superview] != nil) 
	{
		[self cancelMoleculeLoading];
		[tableNavigationController viewWillAppear:YES];
		[glViewController viewWillDisappear:YES];
		[glView removeFromSuperview];
		[self.view addSubview:tableView];
		[glViewController viewDidDisappear:YES];
		[tableNavigationController viewDidAppear:YES];
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
	} 
	else 
	{
		[glViewController viewWillAppear:YES];
		[tableNavigationController viewWillDisappear:YES];
		[tableView removeFromSuperview];
		[self.view addSubview:glView];
		
		[tableNavigationController viewDidDisappear:YES];
		[glViewController viewDidAppear:YES];
		if (bufferedMolecule != previousMolecule)
		{
			previousMolecule = bufferedMolecule;
			[glViewController selectedMoleculeDidChange:bufferedMolecule];
		}
		else
			previousMolecule.isBeingDisplayed = YES;
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque];
	}
	[UIView commitAnimations];
}

#pragma mark -
#pragma mark Passthroughs for managing molecules

- (void)loadInitialMolecule;
{
	NSInteger indexOfInitialMolecule = [[NSUserDefaults standardUserDefaults] integerForKey:@"indexOfLastSelectedMolecule"];
	if (indexOfInitialMolecule >= [molecules count])
		indexOfInitialMolecule = 0;
	[glViewController selectedMoleculeDidChange:[molecules objectAtIndex:indexOfInitialMolecule]];
}

- (void)selectedMoleculeDidChange:(NSInteger)newMoleculeIndex;
{
	if (newMoleculeIndex >= [molecules count])
		newMoleculeIndex = 0;
	[[NSUserDefaults standardUserDefaults] setInteger:newMoleculeIndex forKey:@"indexOfLastSelectedMolecule"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	tableViewController.selectedIndex = newMoleculeIndex;

	// Defer sending the change message to the OpenGL view until the view is loaded, to make sure that rendering occurs only then
	if ([molecules count] == 0)
		bufferedMolecule = nil;
	else
		bufferedMolecule = [molecules objectAtIndex:newMoleculeIndex];
}

#pragma mark -
#pragma mark Passthroughs for managing molecules

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

- (void)cancelMoleculeLoading;
{
	SLSMoleculeGLView *glView = (SLSMoleculeGLView *)glViewController.view;

	if (!glView.moleculeToDisplay.isDoneRendering)
		glView.moleculeToDisplay.isRenderingCancelled = YES;
}

- (void)updateTableListOfMolecules;
{
	UITableView *tableView = (UITableView *)tableViewController.view;
	[tableView reloadData];
}

#pragma mark -
#pragma mark MoleculeDownloadDelegate protocol method

- (void)customURLSelectedForMoleculeDownload:(NSURL *)customURLForMoleculeDownload;
{
	bufferedMolecule = nil;
	[self toggleView];
	//molecules://www.sunsetlakesoftware.com/sites/default/files/xenonPump.pdb
	//html://www.sunsetlakesoftware.com/sites/default/files/xenonPump.pdb
	
	NSString *pathComponentForCustomURL = [[customURLForMoleculeDownload host] stringByAppendingString:[customURLForMoleculeDownload path]];
	NSString *customMoleculeHandlingURL = [NSString stringWithFormat:@"molecules://%@", pathComponentForCustomURL];

	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:customMoleculeHandlingURL]];
}

#pragma mark -
#pragma mark Accessors

@synthesize glViewController;
@synthesize database;
@synthesize molecules;


@end
