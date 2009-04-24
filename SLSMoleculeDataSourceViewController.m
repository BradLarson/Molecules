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

@implementation SLSMoleculeDataSourceViewController

- (id)initWithStyle:(UITableViewStyle)style 
{
	if (self = [super initWithStyle:style]) 
	{
		
		self.navigationItem.title = NSLocalizedStringFromTable(@"Online Data Source", @"Localized", nil);
		self.navigationItem.rightBarButtonItem = nil;
	}
	return self;
}

- (void)dealloc 
{
    [super dealloc];
}


/*
// Implement viewDidLoad to do additional setup after loading the view.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/


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
		cell.textColor = [UIColor blackColor];
	}		
	
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.textColor = [UIColor blackColor];

	switch (index)
	{
		case 0: cell.text = NSLocalizedStringFromTable(@"RCSB Protein Data Bank", @"Localized", nil); break;
		case 1: cell.text = NSLocalizedStringFromTable(@"Custom location", @"Localized", nil); break;
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
			searchViewController.delegate = self;
			
			[self.navigationController pushViewController:searchViewController animated:YES];
			[searchViewController release];
		}; break;
		case 1: 
		{
			// Go to the custom URL download view
			SLSMoleculeCustomDownloadViewController *customURLViewController = [[SLSMoleculeCustomDownloadViewController alloc] initWithNibName:nil bundle:nil];
			customURLViewController.delegate = self;
			
			[self.navigationController pushViewController:customURLViewController animated:YES];
			[customURLViewController release];
		}; break;
	}
	
}


#pragma mark -
#pragma mark MoleculeDownloadDelegate protocol method

- (void)moleculeDownloadController:(SLSMoleculeDownloadViewController *)moleculeDownloadViewController didAddMolecule:(NSData *)moleculeData withFilename:(NSString *)filename;
{
	[self.delegate moleculeDownloadController:moleculeDownloadViewController didAddMolecule:moleculeData withFilename:filename];
}

#pragma mark -
#pragma mark MoleculeDownloadDelegate protocol method

- (void)customURLSelectedForMoleculeDownload:(NSURL *)customURLForMoleculeDownload;
{
	[self.delegate customURLSelectedForMoleculeDownload:customURLForMoleculeDownload];
}


/*- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
    }
    if (editingStyle == UITableViewCellEditingStyleInsert) {
    }
}
*/

/*
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
*/

/*
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
*/


/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
}
*/
/*
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
*/

#pragma mark -
#pragma mark Accessors

@synthesize delegate;


@end

