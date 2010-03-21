//
//  SLSMoleculeDataSourceViewController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 11/9/2008.
//
//  This handles the table view listing the different data sources Molecule supports

#import "SLSMoleculeDataSourceViewController.h"
#import "SLSMoleculeSearchViewController.h"
#import "SLSMoleculeAppDelegate.h"

@implementation SLSMoleculeDataSourceViewController

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithStyle:(UITableViewStyle)style 
{
	if (self = [super initWithStyle:style]) 
	{
		if ([SLSMoleculeAppDelegate isRunningOniPad])
		{
			self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
		}
		
		self.navigationItem.title = NSLocalizedStringFromTable(@"Online Data Source", @"Localized", nil);
		self.navigationItem.rightBarButtonItem = nil;
	}
	return self;
}

- (void)dealloc 
{
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    return YES;
}

#pragma mark -
#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return 2;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	NSInteger index = [indexPath row];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSLocalizedStringFromTable(@"Download", @"Localized", nil)];
	if (cell == nil) 
	{
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:NSLocalizedStringFromTable(@"Download", @"Localized", nil)] autorelease];
		cell.textLabel.textColor = [UIColor blackColor];
	}		
	
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.textLabel.textColor = [UIColor blackColor];

	switch (index)
	{
		case 0: cell.textLabel.text = NSLocalizedStringFromTable(@"RCSB Protein Data Bank", @"Localized", nil); break;
		case 1: cell.textLabel.text = NSLocalizedStringFromTable(@"Custom Location", @"Localized", nil); break;
	}

    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	NSInteger index = [indexPath row];
	switch (index)
	{
		case 0:
		{			
			// Go to the PDB search view
			SLSMoleculeSearchViewController *searchViewController = [[SLSMoleculeSearchViewController alloc] initWithStyle:UITableViewStylePlain];
			
			[self.navigationController pushViewController:searchViewController animated:YES];
			[searchViewController release];
		}; break;
		case 1: 
		{
			// Go to the custom URL download view
			SLSMoleculeCustomDownloadViewController *customURLViewController = [[SLSMoleculeCustomDownloadViewController alloc] initWithNibName:nil bundle:nil];
			
			[self.navigationController pushViewController:customURLViewController animated:YES];
			[customURLViewController release];
		}; break;
	}
	
}

#pragma mark -
#pragma mark MoleculeDownloadDelegate protocol method

/*
- (void)viewDidDisappear:(BOOL)animated {
}
*/

- (void)didReceiveMemoryWarning 
{
}

#pragma mark -
#pragma mark Accessors

@end

