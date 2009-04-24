//
//  SLSMoleculeTableViewController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/30/2008.
//
//  This controller manages the root table of molecules that are stored on the device

#import "SLSMoleculeTableViewController.h"
#import "SLSMoleculeRootViewController.h"
#import "SLSMoleculeDataSourceViewController.h"
#import "SLSMolecule.h"

@implementation SLSMoleculeTableViewController

#pragma mark -
#pragma mark Initialization and breakdown

- (id)initWithStyle:(UITableViewStyle)style initialSelectedMoleculeIndex:(NSInteger)initialSelectedMoleculeIndex;
{
	if (self = [super initWithStyle:style]) 
	{        
        self.title = NSLocalizedStringFromTable(@"Molecules", @"Localized", nil);
		selectedIndex = initialSelectedMoleculeIndex;
        
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
		
        UIBarButtonItem *modelButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"3D Model", @"Localized", nil) style:UIBarButtonItemStylePlain target:self action:@selector(switchBackToGLView)];
        self.navigationItem.leftBarButtonItem = modelButtonItem;
        [modelButtonItem release];

//        self.tableView.rowHeight = 43.0;
		
	}
	return self;
}

- (void)viewDidLoad 
{
}

- (void)dealloc 
{
	[molecules release];
	[super dealloc];
}

#pragma mark -
#pragma mark View switching

- (IBAction)switchBackToGLView;
{
	[self.delegate toggleView];
}

- (IBAction)displayMoleculeDownloadView;
{
	SLSMoleculeDataSourceViewController *dataSourceViewController = [[SLSMoleculeDataSourceViewController alloc] initWithStyle:UITableViewStylePlain];
	dataSourceViewController.delegate = self;
	
	[self.navigationController pushViewController:dataSourceViewController animated:YES];
	[dataSourceViewController release];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}

#pragma mark -
#pragma mark Molecule download delegate methods
- (void)moleculeDownloadController:(SLSMoleculeDownloadViewController *)moleculeDownloadViewController didAddMolecule:(NSData *)moleculeData withFilename:(NSString *)filename;
{
	if (moleculeData != nil)
	{
		// Add the new protein to the list by gunzipping the data and pulling out the title
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = [paths objectAtIndex:0];
		
		NSError *error = nil;
		if (![moleculeData writeToFile:[documentsDirectory stringByAppendingPathComponent:filename] options:NSAtomicWrite error:&error])
		{
			// TODO: Do some error handling here
			return;
		}
		
		SLSMolecule *newMolecule = [[SLSMolecule alloc] initWithFilename:filename database:database];
		if (newMolecule == nil)
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error in downloaded file", @"Localized", nil) message:NSLocalizedStringFromTable(@"The molecule file is either corrupted or not of a supported format", @"Localized", nil)
														   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
			[alert show];
			[alert release];
			
			// Delete the corrupted or sunsupported file
			NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
			NSString *documentsDirectory = [paths objectAtIndex:0];
			
			NSError *error = nil;
			if (![[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:filename] error:&error])
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Could not delete file", @"Localized", nil) message:[error localizedDescription]
															   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
				[alert show];
				[alert release];					
				return;
			}
			
		}
		else
		{
			[molecules addObject:newMolecule];
			[newMolecule release];
			[self.tableView reloadData];
		}			
	}
	[self.navigationController popToViewController:self animated:YES];
	
}

#pragma mark -
#pragma mark MoleculeDownloadDelegate protocol method

- (void)customURLSelectedForMoleculeDownload:(NSURL *)customURLForMoleculeDownload;
{
	NSURL *holderForURL = [customURLForMoleculeDownload copy];
	[self.navigationController popToViewController:self animated:YES];
	[self.delegate customURLSelectedForMoleculeDownload:holderForURL];
	[holderForURL release];
}

#pragma mark -
#pragma mark Table view data source delegate methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
	UITableViewCell *cell;
	NSInteger index = [indexPath row];
	if (index == 0)
	{
		cell = [tableView dequeueReusableCellWithIdentifier:@"Download"];
		if (cell == nil) 
		{
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"Download"] autorelease];
			cell.textColor = [UIColor blackColor];
		}		
		
		cell.text = NSLocalizedStringFromTable(@"Download new molecules", @"Localized", nil);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.textColor = [UIColor blackColor];
	}
	else
	{
		cell = [tableView dequeueReusableCellWithIdentifier:@"Molecules"];
		if (cell == nil) 
		{
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"Molecules"] autorelease];
			cell.textColor = [UIColor blackColor];
			cell.font = [UIFont boldSystemFontOfSize:12.0];
			
			CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 230.0f, 5.0f, 220.0f, 32.0f);
			UILabel *valueLabel = [[UILabel alloc] initWithFrame:frame];
			[valueLabel setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];
			valueLabel.tag = 1;
			valueLabel.textAlignment = UITextAlignmentLeft;
			valueLabel.textColor = [UIColor blackColor];
			valueLabel.font = [UIFont systemFontOfSize:16.0];
			valueLabel.numberOfLines = 1;
			valueLabel.highlightedTextColor = [UIColor whiteColor];
			[cell.contentView addSubview:valueLabel];
			[valueLabel release];
		}
		
		if ((index - 1) == selectedIndex)
			cell.textColor = [UIColor blueColor];
		else
			cell.textColor = [UIColor blackColor];

		NSString *labelForLeftOfName = [[molecules objectAtIndex:(index-1)] filenameWithoutExtension];
		if ([labelForLeftOfName length] > 4)
			labelForLeftOfName = [[labelForLeftOfName substringToIndex:3] stringByAppendingString:@".."];
		cell.text = labelForLeftOfName;
		
		UILabel *valueLabel = (UILabel *)[cell viewWithTag:1];
//		valueLabel.text = [NSString stringWithFormat:@"%@ (%@)", [[molecules objectAtIndex:(index-1)] compound], [[molecules objectAtIndex:(index-1)] title]];
		valueLabel.text = [[molecules objectAtIndex:(index-1)] compound];
		valueLabel.textColor = cell.textColor;
		
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	}
//    NSString *imagePath = [[NSBundle mainBundle] pathForResource:[cell.text lowercaseString]
//                                                          ofType:@"png"];
//    UIImage *icon = [UIImage imageWithContentsOfFile:imagePath];
//    cell.image = icon;
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
	return ([molecules count] + 1);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	NSInteger index = [indexPath row];
	if (index == 0)
		[self displayMoleculeDownloadView];
	else
	{
		selectedIndex = (index - 1);
		
		[self.delegate selectedMoleculeDidChange:(index - 1)];
		[tableView reloadData];
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
	}
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
	NSInteger index = [indexPath row];
	if (index == 0)
		[self displayMoleculeDownloadView];
	else
	{
		// Display detail view for the protein
		SLSMoleculeDetailViewController *detailViewController = [[SLSMoleculeDetailViewController alloc] initWithStyle:UITableViewStyleGrouped andMolecule: [molecules objectAtIndex:(index - 1)]];
		
		[self.navigationController pushViewController:detailViewController animated:YES];
		[detailViewController release];
		
	}
}

// Make sure that the "Download new molecules" item is not deletable
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath;
{
	if ([indexPath row] == 0)
		return UITableViewCellEditingStyleNone;
	else
		return UITableViewCellEditingStyleDelete;
}

// Manage deletion of a protein from disk
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath 
{
	NSInteger index = [indexPath row];
	if (index == 0) // Can't delete the Download new molecules item
		return;
    // If row is deleted, remove it from the list.
    if (editingStyle == UITableViewCellEditingStyleDelete) 
	{
		[[molecules objectAtIndex:(index - 1)] deleteMolecule];
		[molecules removeObjectAtIndex:(index - 1)];
		if ( (index - 1) == selectedIndex )
		{
			if ([molecules count] < 1)
				[self.delegate selectedMoleculeDidChange:0];
			else
			{
				selectedIndex = 0;
				[self.delegate selectedMoleculeDidChange:0];
			}
		}
		else if ( (index - 1) < selectedIndex )
			selectedIndex--;
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
		[tableView reloadData];
    }
}

#pragma mark -
#pragma mark Accessors

@synthesize downloadController;
@synthesize delegate;
@synthesize database;
@synthesize molecules;
@synthesize selectedIndex;

@end
