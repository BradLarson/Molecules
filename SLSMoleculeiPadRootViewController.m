    //
//  SLSMoleculeiPadRootViewController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 2/20/2010.
//
//  The download toolbar icon in this application is courtesy of Joseph Wain / glyphish.com
//  See the GlyphishIconLicense.txt file for more information on these icons


#import "SLSMoleculeiPadRootViewController.h"
#import "SLSMoleculeGLViewController.h"
#import "SLSMoleculeDataSourceViewController.h"

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
	backgroundView.opaque = YES;
	backgroundView.backgroundColor = [UIColor blackColor];
	backgroundView.autoresizesSubviews = YES;
	self.view = backgroundView;
	[backgroundView release];
	
	SLSMoleculeGLViewController *viewController = [[SLSMoleculeGLViewController alloc] initWithNibName:nil bundle:nil];
	self.glViewController = viewController;
	[viewController release];
	
	[self.view addSubview:glViewController.view];
	glViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	mainToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, glViewController.view.frame.size.width, 44.0f)];
	mainToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	mainToolbar.tintColor = [UIColor blackColor];
	[backgroundView addSubview:mainToolbar];

	UIImage *downloadImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"57-download" ofType:@"png"]];	
	UIBarButtonItem *downloadBarButton = [[UIBarButtonItem alloc] initWithImage:downloadImage style:UIBarButtonItemStylePlain target:self action:@selector(showDownloadOptions:)];
	downloadBarButton.width = 44.0f;
	[downloadImage release];
	
	UIImage *visualizationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"VisualizationIcon" ofType:@"png"]];	
	visualizationBarButton = [[UIBarButtonItem alloc] initWithImage:visualizationImage style:UIBarButtonItemStylePlain target:self action:@selector(showVisualizationModes:)];
	visualizationBarButton.width = 44.0f;
	[visualizationImage release];
	
	spacerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

	unselectedRotationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RotationIconiPad" ofType:@"png"]];	
	rotationBarButton = [[UIBarButtonItem alloc] initWithImage:unselectedRotationImage style:UIBarButtonItemStylePlain target:glViewController action:@selector(startOrStopAutorotation:)];
	rotationBarButton.width = 44.0f;
	
	[mainToolbar setItems:[NSArray arrayWithObjects:spacerItem, downloadBarButton, visualizationBarButton, rotationBarButton, nil] animated:NO];
	[downloadBarButton release];

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
	[visualizationBarButton release];
	[spacerItem release];
	[mainToolbar release];
	[selectedRotationImage release];
	[unselectedRotationImage release];
	[rotationBarButton release];
    [super dealloc];
}

#pragma mark -
#pragma mark Bar response methods

/*- (void)showMolecules:(id)sender;
{
	moleculeListPopover = [[UIPopoverController alloc] initWithContentViewController:self.tableNavigationController];
	[self.tableNavigationController setContentSizeForViewInPopover:CGSizeMake(320.0f, round(0.5f * self.view.bounds.size.height))];
	[moleculeListPopover setDelegate:self];
	[moleculeListPopover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}*/

- (void)showVisualizationModes:(id)sender;
{
	if (glViewController.visualizationActionSheet != nil)
		return;
	
	UIActionSheet *actionSheet = [glViewController actionSheetForVisualizationState];
	[actionSheet showFromBarButtonItem:visualizationBarButton animated:YES];
	glViewController.visualizationActionSheet = actionSheet;
	
	[moleculeTablePopover dismissPopoverAnimated:YES];
	moleculeTablePopover = nil;
	
	[downloadOptionsPopover dismissPopoverAnimated:YES];
	[downloadOptionsPopover release];
	downloadOptionsPopover = nil;
}

- (void)showDownloadOptions:(id)sender;
{
	if (downloadOptionsPopover != nil)
		return;
	
	UINavigationController *downloadNavigationController = [[UINavigationController alloc] init];
	downloadNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	
	SLSMoleculeDataSourceViewController *dataSourceViewController = [[SLSMoleculeDataSourceViewController alloc] initWithStyle:UITableViewStylePlain];
//	dataSourceViewController.delegate = self;
	[downloadNavigationController pushViewController:dataSourceViewController animated:NO];
	[dataSourceViewController release];
	
	downloadOptionsPopover = [[UIPopoverController alloc] initWithContentViewController:downloadNavigationController];
	[downloadNavigationController release];
	[downloadOptionsPopover setDelegate:self];
	[downloadOptionsPopover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
//	[downloadOptionsPopover release];
	
	[glViewController.visualizationActionSheet dismissWithClickedButtonIndex:2 animated:YES];
	glViewController.visualizationActionSheet = nil;

	[moleculeTablePopover dismissPopoverAnimated:YES];
	moleculeTablePopover = nil;
	
}

#pragma mark -
#pragma mark Passthroughs for managing molecules

- (void)selectedMoleculeDidChange:(NSInteger)newMoleculeIndex;
{
	[super selectedMoleculeDidChange:newMoleculeIndex];
	
	glViewController.moleculeToDisplay = bufferedMolecule;
	
	[moleculeTablePopover dismissPopoverAnimated:YES];
	moleculeTablePopover = nil;
}

#pragma mark -
#pragma mark Manage the switching of rotation state

- (void)toggleRotationButton:(NSNotification *)note;
{
	if ([[note object] boolValue])
	{
		if (selectedRotationImage == nil)
			selectedRotationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RotationIconiPadCancel" ofType:@"png"]];
		
		rotationBarButton.image = selectedRotationImage;
	}
	else
	{
		rotationBarButton.image = unselectedRotationImage;
	}
}

#pragma mark -
#pragma mark UISplitViewControllerDelegate methods

- (void)splitViewController:(UISplitViewController*)svc popoverController:(UIPopoverController*)pc willPresentViewController:(UIViewController *)aViewController
{
	[downloadOptionsPopover dismissPopoverAnimated:YES];
	[downloadOptionsPopover release];
	downloadOptionsPopover = nil;
//	[downloadOptionsPopover release];
	
	[glViewController.visualizationActionSheet dismissWithClickedButtonIndex:2 animated:YES];
	glViewController.visualizationActionSheet = nil;
	
	moleculeTablePopover = pc;
}

- (void)splitViewController:(UISplitViewController*)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem*)barButtonItem forPopoverController:(UIPopoverController*)pc
{		
	[(UINavigationController *)aViewController navigationBar].barStyle = UIBarStyleBlackOpaque;
//    barButtonItem.title = @"Molecules";
    NSMutableArray *items = [[mainToolbar items] mutableCopy];
    [items insertObject:barButtonItem atIndex:0];
    [mainToolbar setItems:items animated:YES];
    [items release];
}

- (void)splitViewController:(UISplitViewController*)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)button
{
	[(UINavigationController *)aViewController navigationBar].barStyle = UIBarStyleBlackOpaque;

    NSMutableArray *items = [[mainToolbar items] mutableCopy];
    [items removeObjectAtIndex:0];
    [mainToolbar setItems:items animated:YES];
    [items release];
}	

#pragma mark -
#pragma mark UIPopoverControllerDelegate methods

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController;
{
	if (popoverController == downloadOptionsPopover)
	{
		[downloadOptionsPopover release];
		downloadOptionsPopover = nil;
	}
	else if (popoverController == moleculeTablePopover)
	{
		moleculeTablePopover = nil;
	}
}


#pragma mark -
#pragma mark Accessors

@end
