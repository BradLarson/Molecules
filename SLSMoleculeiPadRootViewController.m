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
#import "SLSMoleculeGLView.h"
#import "SLSAtomColorKeyController.h"

@implementation SLSMoleculeiPadRootViewController

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView 
{
	CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];

	UIView *backgroundView = [[UIView alloc] initWithFrame:mainScreenFrame];
	backgroundView.opaque = YES;
	backgroundView.backgroundColor = [UIColor blackColor];
	backgroundView.autoresizesSubviews = YES;
	self.view = backgroundView;
	
	SLSMoleculeGLViewController *viewController = [[SLSMoleculeGLViewController alloc] initWithNibName:nil bundle:nil];
	self.glViewController = viewController;
	
	[self.view addSubview:glViewController.view];
	glViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	mainToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, glViewController.view.frame.size.width, 44.0f)];
	mainToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	mainToolbar.tintColor = [UIColor blackColor];
	[backgroundView addSubview:mainToolbar];
    
	UIImage *screenImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"98-palette" ofType:@"png"]];	
	colorKeyBarButton = [[UIBarButtonItem alloc] initWithImage:screenImage style:UIBarButtonItemStylePlain target:self action:@selector(showColorKey:)];
	colorKeyBarButton.width = 44.0f;
	
	UIImage *visualizationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"VisualizationIcon" ofType:@"png"]];	
	visualizationBarButton = [[UIBarButtonItem alloc] initWithImage:visualizationImage style:UIBarButtonItemStylePlain target:self action:@selector(showVisualizationModes:)];
	visualizationBarButton.width = 44.0f;
	
	spacerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

	unselectedRotationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RotationIconiPad" ofType:@"png"]];	
	rotationBarButton = [[UIBarButtonItem alloc] initWithImage:unselectedRotationImage style:UIBarButtonItemStylePlain target:glViewController action:@selector(startOrStopAutorotation:)];
	rotationBarButton.width = 44.0f;
	
    [mainToolbar setItems:[NSArray arrayWithObjects:spacerItem, colorKeyBarButton, visualizationBarButton, rotationBarButton, nil] animated:NO];
		
	glViewController.view.frame = CGRectMake(mainScreenFrame.origin.x, mainToolbar.bounds.size.height, mainScreenFrame.size.width, mainScreenFrame.size.height -  mainToolbar.bounds.size.height);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    // Overriden to allow any orientation.
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [glViewController handleStartOfAutorotation];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [glViewController handleEndOfAutorotation];
}

- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload 
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


#pragma mark -
#pragma mark Bar response methods

- (void)showVisualizationModes:(id)sender;
{
	if (glViewController.visualizationActionSheet != nil)
    {
		return;
    }
	
	UIActionSheet *actionSheet = [glViewController actionSheetForVisualizationState];
	[actionSheet showFromBarButtonItem:visualizationBarButton animated:YES];
	glViewController.visualizationActionSheet = actionSheet;
	
	[moleculeTablePopover dismissPopoverAnimated:YES];
	moleculeTablePopover = nil;
	
	[downloadOptionsPopover dismissPopoverAnimated:YES];
	downloadOptionsPopover = nil;
    
    [colorKeyPopover dismissPopoverAnimated:YES];
	colorKeyPopover = nil;
}

- (void)showDownloadOptions:(id)sender;
{
	if (downloadOptionsPopover != nil)
    {
		return;
    }
	
	UINavigationController *downloadNavigationController = [[UINavigationController alloc] init];
	downloadNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	
	SLSMoleculeDataSourceViewController *dataSourceViewController = [[SLSMoleculeDataSourceViewController alloc] initWithStyle:UITableViewStylePlain];
//	dataSourceViewController.delegate = self;
	[downloadNavigationController pushViewController:dataSourceViewController animated:NO];
	
	downloadOptionsPopover = [[UIPopoverController alloc] initWithContentViewController:downloadNavigationController];
	[downloadOptionsPopover setDelegate:self];
	[downloadOptionsPopover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
//	[downloadOptionsPopover release];
	
	[glViewController.visualizationActionSheet dismissWithClickedButtonIndex:2 animated:YES];
	glViewController.visualizationActionSheet = nil;

	[moleculeTablePopover dismissPopoverAnimated:YES];
	moleculeTablePopover = nil;
	
	[colorKeyPopover dismissPopoverAnimated:YES];
	colorKeyPopover = nil;
}

- (void)showColorKey:(id)sender;
{
	if (colorKeyPopover != nil)
    {
		return;
    }
	
	UINavigationController *colorKeyNavigationController = [[UINavigationController alloc] init];
	colorKeyNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	
	SLSAtomColorKeyController *dataSourceViewController = [[SLSAtomColorKeyController alloc] initWithStyle:UITableViewStylePlain];
	[colorKeyNavigationController pushViewController:dataSourceViewController animated:NO];
	
	colorKeyPopover = [[UIPopoverController alloc] initWithContentViewController:colorKeyNavigationController];
	[colorKeyPopover setDelegate:self];
	[colorKeyPopover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	
	[glViewController.visualizationActionSheet dismissWithClickedButtonIndex:2 animated:YES];
	glViewController.visualizationActionSheet = nil;
    
	[moleculeTablePopover dismissPopoverAnimated:YES];
	moleculeTablePopover = nil;
	
	[downloadOptionsPopover dismissPopoverAnimated:YES];
	downloadOptionsPopover = nil;
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
        {
			selectedRotationImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RotationIconiPadCancel" ofType:@"png"]];
        }
		
		rotationBarButton.image = selectedRotationImage;
	}
	else
	{
		rotationBarButton.image = unselectedRotationImage;
	}
}

#pragma mark -
#pragma mark External monitor support

- (void)handleConnectionOfMonitor:(NSNotification *)note;
{
	externalScreen = [note object];
	NSMutableArray *items = [[mainToolbar items] mutableCopy];
//    [items insertObject:screenBarButton atIndex:[items indexOfObject:spacerItem] + 1];
    [mainToolbar setItems:items animated:YES];
}

- (void)handleDisconnectionOfMonitor:(NSNotification *)note;
{
	NSMutableArray *items = [[mainToolbar items] mutableCopy];
//    [items removeObject:screenBarButton];
    [mainToolbar setItems:items animated:YES];
	
	if (externalWindow != nil)
	{
		[self.view addSubview:glViewController.view];
		[glViewController updateSizeOfGLView:nil];
		externalWindow = nil;
	}
	externalScreen = nil;
}

- (void)displayOnExternalOrLocalScreen:(id)sender;
{
	if (externalWindow != nil)
	{
		// External window exists, need to move back locally
		[self.view addSubview:glViewController.view];
		CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];
		glViewController.view.frame = CGRectMake(mainScreenFrame.origin.x, mainToolbar.bounds.size.height, mainScreenFrame.size.width, mainScreenFrame.size.height -  mainToolbar.bounds.size.height);

		// Move view back to local window
		externalWindow = nil;
	}
	else
	{
		// Being displayed locally, move to external window
		CGRect externalBounds = [externalScreen bounds];
		externalWindow = [[UIWindow alloc] initWithFrame:externalBounds];
		externalWindow.backgroundColor = [UIColor whiteColor];
		externalWindow.screen = externalScreen;
		
		
//		if (glViewController.is
		
//		[glViewController.view removeFromSuperview];
//		glViewController.view = nil;
//		
//		glViewController.view = [[SLSMoleculeGLView alloc] initWithFrame:externalBounds];

		
//		SLSMoleculeGLView *glView = (SLSMoleculeGLView *)glViewController.view;
//		[EAGLContext setCurrentContext:glView.context];
//		[opengl destroyFramebuffer];
		
		
//		glView.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
		[externalWindow addSubview:glViewController.view];

//		[EAGLContext setCurrentContext:glView.context];		
//		[glView createFramebuffer];
//		[glView configureProjection];
//		[glViewController _drawViewByRotatingAroundX:0.0f rotatingAroundY:0.0f scaling:1.0f translationInX:0.0f translationInY:0.0f];	
		
//		UILabel *helloWorld = [[UILabel alloc] initWithFrame:CGRectMake(200.0f, 400.0f, 400.0f, 60.0f)];
//		helloWorld.text = @"This page intentionally left blank.";
//		[externalWindow addSubview:helloWorld];
//		[helloWorld release];
		
		glViewController.view.frame = externalBounds;		
		[externalWindow makeKeyAndVisible];
	}
}

#pragma mark -
#pragma mark UISplitViewControllerDelegate methods

- (void)splitViewController:(UISplitViewController*)svc popoverController:(UIPopoverController*)pc willPresentViewController:(UIViewController *)aViewController
{
	[downloadOptionsPopover dismissPopoverAnimated:YES];
	downloadOptionsPopover = nil;
	
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
}

- (void)splitViewController:(UISplitViewController*)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)button
{
	[(UINavigationController *)aViewController navigationBar].barStyle = UIBarStyleBlackOpaque;

    NSMutableArray *items = [[mainToolbar items] mutableCopy];
    [items removeObjectAtIndex:0];
    [mainToolbar setItems:items animated:YES];
}	

#pragma mark -
#pragma mark UIPopoverControllerDelegate methods

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController;
{
	if (popoverController == downloadOptionsPopover)
	{
		downloadOptionsPopover = nil;
	}
	else if (popoverController == moleculeTablePopover)
	{
		moleculeTablePopover = nil;
	}
	else if (popoverController == colorKeyPopover)
	{
		colorKeyPopover = nil;
	}
}


#pragma mark -
#pragma mark Accessors

@end
