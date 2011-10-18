//
//  SLSMoleculeRootViewController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/30/2008.
//
//  This controller manages a root view into which the 3D view and the molecule table selection views and animated for the neat flipping effect

#import "SLSMoleculeAppDelegate.h"
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
    if ((self = [super init])) 
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleView:) name:@"ToggleView" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleRotationButton:) name:@"ToggleRotationSelected" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(customURLSelectedForMoleculeDownload:) name:@"CustomURLForMoleculeSelected" object:nil];
    }
    return self;
}


- (void)loadView 
{
	CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];
	
	UIView *backgroundView = [[UIView alloc] initWithFrame:mainScreenFrame];
	backgroundView.backgroundColor = [UIColor blackColor];
		
	self.view = backgroundView;
	toggleViewDisabled = NO;

	SLSMoleculeGLViewController *viewController = [[SLSMoleculeGLViewController alloc] initWithNibName:nil bundle:nil];
	self.glViewController = viewController;
	
	[self.view addSubview:glViewController.view];
	
	UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
	infoButton.frame = CGRectMake(320.0f - 70.0f, 460.0f - 70.0f, 70.0f, 70.0f);
	[infoButton addTarget:glViewController action:@selector(switchToTableView) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
	[glViewController.view addSubview:infoButton];
	
	rotationButton = [UIButton buttonWithType:UIButtonTypeCustom];
	
	UIImage *rotationImage = [UIImage imageNamed:@"RotationIcon.png"];
	if (rotationImage == nil)
	{
		rotationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RotationIcon" ofType:@"png"]];
	}
	[rotationButton setImage:rotationImage forState:UIControlStateNormal];
	
	UIImage *selectedRotationImage = [UIImage imageNamed:@"RotationIconSelected.png"];
	if (selectedRotationImage == nil)
	{
		selectedRotationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RotationIconSelected" ofType:@"png"]];
	}
	[rotationButton setImage:selectedRotationImage forState:UIControlStateSelected];
	
	rotationButton.showsTouchWhenHighlighted = YES;
	[rotationButton addTarget:glViewController action:@selector(startOrStopAutorotation:) forControlEvents:UIControlEventTouchUpInside];
	rotationButton.frame = CGRectMake(0.0f, 460.0f - 70.0f, 70.0f, 70.0f);
	rotationButton.clipsToBounds = NO;
	[glViewController.view addSubview:rotationButton];
}

- (void)toggleView:(NSNotification *)note;
{	
	if (molecules == nil)
		return;
	
	UIView *tableView = self.tableNavigationController.view;
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
	{
		indexOfInitialMolecule = 0;
	}
	
	if ([molecules count] > 0)
	{
		glViewController.moleculeToDisplay = [molecules objectAtIndex:indexOfInitialMolecule];
	}
}

- (void)selectedMoleculeDidChange:(NSInteger)newMoleculeIndex;
{
	if (newMoleculeIndex >= [molecules count])
	{
		newMoleculeIndex = 0;		
	}
	
	[[NSUserDefaults standardUserDefaults] setInteger:newMoleculeIndex forKey:@"indexOfLastSelectedMolecule"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	tableViewController.selectedIndex = newMoleculeIndex;

	// Defer sending the change message to the OpenGL view until the view is loaded, to make sure that rendering occurs only then
	if ([molecules count] == 0)
	{
		bufferedMolecule = nil;
	}
	else
	{
		bufferedMolecule = [molecules objectAtIndex:newMoleculeIndex];
	}
}

#pragma mark -
#pragma mark UIViewController methods

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	// Only allow free autorotation on the iPad
	if ([SLSMoleculeAppDelegate isRunningOniPad])
	{
		return YES;
	}
	else
	{
		return (interfaceOrientation == UIInterfaceOrientationPortrait);
	}
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
#pragma mark Manage the switching of rotation state

- (void)toggleRotationButton:(NSNotification *)note;
{
	if ([[note object] boolValue])
	{
		rotationButton.selected = YES;
	}
	else
	{
		rotationButton.selected = NO;
	}
}

- (void)customURLSelectedForMoleculeDownload:(NSNotification *)note;
{
	NSURL *customURLForMoleculeDownload = [note object];
	
	bufferedMolecule = nil;
	
	if (![SLSMoleculeAppDelegate isRunningOniPad])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleView" object:nil];
	}
	//molecules://www.sunsetlakesoftware.com/sites/default/files/xenonPump.pdb
	//html://www.sunsetlakesoftware.com/sites/default/files/xenonPump.pdb
	
	NSString *pathComponentForCustomURL = [[customURLForMoleculeDownload host] stringByAppendingString:[customURLForMoleculeDownload path]];
	NSString *customMoleculeHandlingURL = [NSString stringWithFormat:@"molecules://%@", pathComponentForCustomURL];

//	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:customMoleculeHandlingURL]];
	[(SLSMoleculeAppDelegate *)[[UIApplication sharedApplication] delegate] handleCustomURLScheme:[NSURL URLWithString:customMoleculeHandlingURL]];
}

#pragma mark -
#pragma mark Accessors

@synthesize tableNavigationController;
@synthesize tableViewController;
@synthesize glViewController;
@synthesize database;
@synthesize molecules;

- (void)setDatabase:(sqlite3 *)newValue
{
	database = newValue;
	tableViewController.database = database;
}

- (void)setMolecules:(NSMutableArray *)newValue;
{
	if (molecules == newValue)
	{
		return;
	}
	
	molecules = newValue;
	tableViewController.molecules = molecules;
	
	NSInteger indexOfInitialMolecule = [[NSUserDefaults standardUserDefaults] integerForKey:@"indexOfLastSelectedMolecule"];
	if (indexOfInitialMolecule >= [molecules count])
	{
		indexOfInitialMolecule = 0;
	}
	
	tableViewController.selectedIndex = indexOfInitialMolecule;
}

- (UINavigationController *)tableNavigationController;
{
	if (tableNavigationController == nil)
	{
		bufferedMolecule = nil;
		tableNavigationController = [[UINavigationController alloc] init];
		if ([SLSMoleculeAppDelegate isRunningOniPad])
		{
			tableNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
		}

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
	
	return tableNavigationController;
}



@end
