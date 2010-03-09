    //
//  SLSMoleculeiPadRootViewController.m
//  Molecules
//
//  Created by Brad Larson on 2/20/2010.
//  Copyright 2010 Sunset Lake Software LLC. All rights reserved.
//

#import "SLSMoleculeiPadRootViewController.h"
#import "SLSMoleculeGLViewController.h"

@implementation SLSMoleculeiPadRootViewController

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView 
{
	CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];

	UIView *backgroundView = [[UIView alloc] initWithFrame:mainScreenFrame];
	backgroundView.backgroundColor = [UIColor whiteColor];
	self.view = backgroundView;
	[backgroundView release];
	
	SLSMoleculeGLViewController *viewController = [[SLSMoleculeGLViewController alloc] initWithNibName:nil bundle:nil];
	self.glViewController = viewController;
	[viewController release];
	
	[self.view addSubview:glViewController.view];

	UIToolbar *mainToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, mainScreenFrame.size.width, 44.0f)];
	mainToolbar.tintColor = [UIColor blackColor];
	[backgroundView addSubview:mainToolbar];
	
	UIBarButtonItem *libraryBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Molecules" style:UIBarButtonItemStyleBordered target:self action:@selector(showMolecules:)];
	UIBarButtonItem *visualizationBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Visualization Modes" style:UIBarButtonItemStyleBordered target:self action:@selector(showVisualizationModes:)];
	UIBarButtonItem *spacerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

	unselectedRotationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RotationIcon" ofType:@"png"]];	
	rotationBarButton = [[UIBarButtonItem alloc] initWithImage:unselectedRotationImage style:UIBarButtonItemStyleBordered target:glViewController action:@selector(startOrStopAutorotation:)];
	
	[mainToolbar setItems:[NSArray arrayWithObjects:libraryBarButton, spacerItem, visualizationBarButton, rotationBarButton, nil] animated:NO];

	[visualizationBarButton release];
	[spacerItem release];
	[libraryBarButton release];
	
	
	[mainToolbar release];

	glViewController.view.frame = CGRectMake(mainScreenFrame.origin.x, mainToolbar.bounds.size.height, mainScreenFrame.size.width, mainScreenFrame.size.height -  mainToolbar.bounds.size.height);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overriden to allow any orientation.
    return YES;
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc 
{
	[selectedRotationImage release];
	[unselectedRotationImage release];
	[rotationBarButton release];
    [super dealloc];
}

#pragma mark -
#pragma mark Bar response methods

- (void)showMolecules:(id)sender;
{
	if (tableNavigationController == nil) 
	{
		[self loadTableViewController];
	}
	
	moleculeListPopover = [[UIPopoverController alloc] initWithContentViewController:tableNavigationController];
	[tableNavigationController setContentSizeForViewInPopover:CGSizeMake(320.0f, round(0.5f * self.view.bounds.size.height))];
	[moleculeListPopover setDelegate:self];
	[moleculeListPopover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void)showVisualizationModes:(id)sender;
{
	
}

#pragma mark -
#pragma mark Manage the switching of rotation state

- (void)toggleRotationButton:(NSNotification *)note;
{
	if ([[note object] boolValue])
	{
		if (selectedRotationImage == nil)
			selectedRotationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RotationIconSelected" ofType:@"png"]];
		
		rotationBarButton.image = selectedRotationImage;
	}
	else
	{
		rotationBarButton.image = unselectedRotationImage;
	}
}

#pragma mark -
#pragma mark UIPopoverControllerDelegate methods

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController

{
	return YES;
}

@end
