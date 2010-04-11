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
#import "SLSMoleculeAppDelegate.h"

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
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moleculeDidFinishDownloading:) name:@"MoleculeDidFinishDownloading" object:nil];

		
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		{
			self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
		}
		
		if ([SLSMoleculeAppDelegate isRunningOniPad])
		{
//			self.tableView.backgroundColor = [UIColor blackColor];
//			tableTextColor = [[UIColor whiteColor] retain];
			self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
		}
		else
		{
//			tableTextColor = [[UIColor blackColor] retain];
			UIBarButtonItem *modelButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"3D Model", @"Localized", nil) style:UIBarButtonItemStylePlain target:self action:@selector(switchBackToGLView)];
			self.navigationItem.leftBarButtonItem = modelButtonItem;
			[modelButtonItem release];
		}
	}
	return self;
}

- (void)viewDidLoad 
{
}

- (void)dealloc 
{
	[tableTextColor release];
	[molecules release];
	[super dealloc];
}

#pragma mark -
#pragma mark View switching

- (IBAction)switchBackToGLView;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleView" object:nil];
}

- (IBAction)displayMoleculeDownloadView;
{
	SLSMoleculeDataSourceViewController *dataSourceViewController = [[SLSMoleculeDataSourceViewController alloc] initWithStyle:UITableViewStylePlain];
	
	[self.navigationController pushViewController:dataSourceViewController animated:YES];
	[dataSourceViewController release];
}

- (void)moleculeDidFinishDownloading:(NSNotification *)note;
{
	NSString *filename = [note object];
	
	// Add the new protein to the list by gunzipping the data and pulling out the title
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
		
//		[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:([molecules count] - 1) inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];		
	}			

	[self.navigationController popToViewController:self animated:YES];
}

#pragma mark -
#pragma mark Table view data source delegate methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
	UITableViewCell *cell;
	NSInteger index = [indexPath row];
	
	if ([SLSMoleculeAppDelegate isRunningOniPad])
		index++;
	
	if (index == 0)
	{
		cell = [tableView dequeueReusableCellWithIdentifier:@"Download"];
		if (cell == nil) 
		{
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Download"] autorelease];
			cell.textLabel.textColor = [UIColor blackColor];
		}		
		
		cell.textLabel.text = NSLocalizedStringFromTable(@"Download new molecules", @"Localized", nil);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.textLabel.textColor = [UIColor blackColor];
	}
	else
	{
		cell = [tableView dequeueReusableCellWithIdentifier:@"Molecules"];
		if (cell == nil) 
		{
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Molecules"] autorelease];
			cell.textLabel.textColor = [UIColor blackColor];
		}
		
		if ((index - 1) == selectedIndex)
			cell.textLabel.textColor = [UIColor blueColor];
		else
			cell.textLabel.textColor = [UIColor blackColor];

		cell.textLabel.text = [[molecules objectAtIndex:(index-1)] compound];

		NSString *fileNameWithoutExtension = [[molecules objectAtIndex:(index-1)] filenameWithoutExtension];
		cell.detailTextLabel.text = fileNameWithoutExtension;
		
		
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	}

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
	if ([SLSMoleculeAppDelegate isRunningOniPad])
	{
		return [molecules count];
	}
	else
	{		
		return ([molecules count] + 1);
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	NSInteger index = [indexPath row];
	if ([SLSMoleculeAppDelegate isRunningOniPad])
		index++;
	
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
	if ([SLSMoleculeAppDelegate isRunningOniPad])
		index++;
	
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
	if ([SLSMoleculeAppDelegate isRunningOniPad])
	{
		return UITableViewCellEditingStyleDelete;
	}
	else
	{
		if ([indexPath row] == 0)
			return UITableViewCellEditingStyleNone;
		else
			return UITableViewCellEditingStyleDelete;
	}	
}

// Manage deletion of a protein from disk
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath 
{
	NSInteger index = [indexPath row];
	if ([SLSMoleculeAppDelegate isRunningOniPad])
		index++;
	
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

- (void)didReceiveMemoryWarning
{
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overriden to allow any orientation.
    return YES;
}



#pragma mark -
#pragma mark Accessors

@synthesize downloadController;
@synthesize delegate;
@synthesize database;
@synthesize molecules;
@synthesize selectedIndex;

@end
