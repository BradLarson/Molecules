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

- (id)init; 
{
    if (self = [super init]) 
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleView:) name:@"ToggleView" object:nil];
    }
    return self;
}

- (void)dealloc 
{
	[tableViewController release];
	[glViewController release];
	[tableNavigationController release];
	[super dealloc];
}

- (void)viewDidLoad 
{
	toggleViewDisabled = NO;

	SLSMoleculeGLViewController *viewController = [[SLSMoleculeGLViewController alloc] initWithNibName:nil bundle:nil];
	self.glViewController = viewController;
	[viewController release];
	
	[self.view addSubview:glViewController.view];
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

- (void)toggleView:(NSNotification *)note;
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
			glViewController.moleculeToDisplay = bufferedMolecule;
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
	
	if ([molecules count] > 0)
		glViewController.moleculeToDisplay = [molecules objectAtIndex:indexOfInitialMolecule];
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
}

- (void)cancelMoleculeLoading;
{
	if (!glViewController.moleculeToDisplay.isDoneRendering)
	{
		glViewController.moleculeToDisplay.isRenderingCancelled = YES;
		[NSThread sleepForTimeInterval:0.1];
	}
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
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleView" object:nil];
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
