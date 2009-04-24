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

- (void)dealloc 
{
	[super dealloc];
}

- (void)viewDidLoad 
{
//	SLSMoleculeGLView *glView = (SLSMoleculeGLView *)self.view;
//	[glView drawView];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) 
	{
		// Custom initialization
	}
	return self;
}

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
