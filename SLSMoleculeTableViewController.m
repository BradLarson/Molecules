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
#import "SLSMoleculeSearchViewController.h"
#import "SLSMolecule.h"
#import "SLSMoleculeAppDelegate.h"
#import "SLSMoleculeLibraryTableCell.h"

@implementation SLSMoleculeTableViewController

#pragma mark -
#pragma mark Initialization and breakdown

- (id)initWithStyle:(UITableViewStyle)style initialSelectedMoleculeIndex:(NSInteger)initialSelectedMoleculeIndex;
{
	if ((self = [super initWithStyle:style])) 
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

			UIBarButtonItem *downloadButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(displayMoleculeDownloadView)];
			self.navigationItem.leftBarButtonItem = downloadButtonItem;
		}
		else
		{
//			tableTextColor = [[UIColor blackColor] retain];
			UIBarButtonItem *modelButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"3D Model", @"Localized", nil) style:UIBarButtonItemStylePlain target:self action:@selector(switchBackToGLView)];
			self.navigationItem.leftBarButtonItem = modelButtonItem;
		}
	}
	return self;
}

- (void)viewDidLoad;
{
	[super viewDidLoad];
    
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
		//		self.tableView.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.054f alpha:1.0f];
		self.tableView.backgroundColor = [UIColor blackColor];
        self.tableView.separatorColor = [UIColor clearColor];
        self.tableView.rowHeight = 50.0;
        
//        CAGradientLayer *shadowGradient = [SLSMoleculeTableViewController shadowGradientForSize:CGSizeMake(320.0f, self.navigationController.view.frame.size.height)];
//		[self.navigationController.view.layer setMask:shadowGradient];
//		self.navigationController.view.layer.masksToBounds = NO;
	}
	else
	{
		self.tableView.backgroundColor = [UIColor whiteColor];
	}	
}


#pragma mark -
#pragma mark View switching

- (IBAction)switchBackToGLView;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleView" object:nil];
}

- (IBAction)displayMoleculeDownloadView;
{
    SLSMoleculeSearchViewController *searchViewController = [[SLSMoleculeSearchViewController alloc] initWithStyle:UITableViewStylePlain];
    
    [self.navigationController pushViewController:searchViewController animated:YES];

/*    
	SLSMoleculeDataSourceViewController *dataSourceViewController = [[SLSMoleculeDataSourceViewController alloc] initWithStyle:UITableViewStylePlain];
	
	[self.navigationController pushViewController:dataSourceViewController animated:YES];
	[dataSourceViewController release];
 */
}

- (void)moleculeDidFinishDownloading:(NSNotification *)note;
{
    if ([note object] == nil)
    {
        [self.navigationController popToViewController:self animated:YES];
        return;
    }
    
	NSString *filename = [note object];
	
	// Add the new protein to the list by gunzipping the data and pulling out the title
    
	SLSMolecule *newMolecule = [[SLSMolecule alloc] initWithFilename:filename database:database title:[[note userInfo] objectForKey:@"title"]];
	if (newMolecule == nil)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error in downloaded file", @"Localized", nil) message:NSLocalizedStringFromTable(@"The molecule file is either corrupted or not of a supported format", @"Localized", nil)
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
		[alert show];
		
		// Delete the corrupted or sunsupported file
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = [paths objectAtIndex:0];
		
		NSError *error = nil;
		if (![[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:filename] error:&error])
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Could not delete file", @"Localized", nil) message:[error localizedDescription]
														   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
			[alert show];
			return;
		}
		
	}
	else
	{
		[molecules addObject:newMolecule];
		
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            selectedIndex = ([molecules count] - 1);

            [self.delegate selectedMoleculeDidChange:selectedIndex];            
        }

        [self.tableView reloadData];
//		[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:([molecules count] - 1) inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];		
	}			

	[self.navigationController popToViewController:self animated:YES];
}

#pragma mark -
#pragma mark Table customization

+ (CAGradientLayer *)glowGradientForSize:(CGSize)gradientSize;
{
	CAGradientLayer *newGlow = [[CAGradientLayer alloc] init];
	//	self.tableView.rowHeight = 20.0f + MAXHEIGHTFOREQUATIONSINTABLEVIEW;
	
	CGRect newGlowFrame = CGRectMake(0, 0, gradientSize.width, gradientSize.height);
	newGlow.frame = newGlowFrame;
	UIColor *topColor = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.20f];
	UIColor *middleColor = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.0f];
	UIColor *bottomColor = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.08f];
    
	newGlow.colors = [NSArray arrayWithObjects:(id)[topColor CGColor], (id)[middleColor CGColor], (id)[bottomColor CGColor], nil];
	return newGlow;
}

+ (CAGradientLayer *)shadowGradientForSize:(CGSize)gradientSize;
{
	CAGradientLayer *newShadow = [[CAGradientLayer alloc] init];
	newShadow.startPoint = CGPointMake(1.0f, 0.5);
	newShadow.endPoint = CGPointMake(0.9f, 0.5);
	
	CGRect newShadowFrame = CGRectMake(0, 0, gradientSize.width, gradientSize.height);
	newShadow.frame = newShadowFrame;
	UIColor *rightColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.5f];
	UIColor *leftColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
	newShadow.colors = [NSArray arrayWithObjects:(id)[rightColor CGColor], (id)[leftColor CGColor], nil];
	return newShadow;
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
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Download"];
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            {
                cell.backgroundColor = [UIColor blackColor];
                cell.textLabel.textColor = [UIColor whiteColor];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            else
            {
                cell.textLabel.textColor = [UIColor blackColor];
            }

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
			cell = [[SLSMoleculeLibraryTableCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Molecules"];

            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            {
                cell.backgroundColor = [UIColor blackColor];
                cell.textLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                CAGradientLayer *glowGradientLayer = [SLSMoleculeTableViewController glowGradientForSize:CGSizeMake(self.view.frame.size.width, 50.0)];
                [(SLSMoleculeLibraryTableCell *)cell setHighlightGradientLayer:glowGradientLayer];
                
                [cell.layer insertSublayer:glowGradientLayer atIndex:10];
            }
            else
            {
                cell.textLabel.textColor = [UIColor blackColor];
            }
		}
		
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            if ((index - 1) == selectedIndex)
            {
                cell.textLabel.textColor = [UIColor colorWithRed:0 green:0.73 blue:0.95 alpha:1.0];
                
                if (![(SLSMoleculeLibraryTableCell *)cell isSelected])
                {
                    CAGradientLayer *glowGradient = [(SLSMoleculeLibraryTableCell *)cell highlightGradientLayer];
                    UIColor *topColor = [UIColor colorWithRed:0.5f green:0.7f blue:1.0f alpha:0.6f];
                    UIColor *middleColor = [UIColor colorWithRed:0.5f green:0.7f blue:1.0f alpha:0.1f];
                    UIColor *bottomColor = [UIColor colorWithRed:0.5585f green:0.672f blue:1.0f alpha:0.30f];
                    glowGradient.colors = [NSArray arrayWithObjects:(id)[topColor CGColor], (id)[middleColor CGColor], (id)[bottomColor CGColor], nil];
                    
                    [(SLSMoleculeLibraryTableCell *)cell setIsSelected:YES];
                }
            }
            else
            {
                cell.textLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
                
                if ([(SLSMoleculeLibraryTableCell *)cell isSelected])
                {
                    CAGradientLayer *glowGradient = [(SLSMoleculeLibraryTableCell *)cell highlightGradientLayer];
                    UIColor *topColor = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.20f];
                    UIColor *middleColor = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.0f];
                    UIColor *bottomColor = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.08f];
                    glowGradient.colors = [NSArray arrayWithObjects:(id)[topColor CGColor], (id)[middleColor CGColor], (id)[bottomColor CGColor], nil];

                    [(SLSMoleculeLibraryTableCell *)cell setIsSelected:NO];
                }
            }
        }
        else
        {
            if ((index - 1) == selectedIndex)
            {
                cell.textLabel.textColor = [UIColor blueColor];
            }
            else
            {
                cell.textLabel.textColor = [UIColor blackColor];
            }
        }

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
	{
		index++;
        indexPath = [NSIndexPath indexPathForRow:index inSection:[indexPath section]];
	}
	
	if (index == 0)
	{
		[self displayMoleculeDownloadView];
	}
	else
	{
		selectedIndex = (index - 1);
		
		[self.delegate selectedMoleculeDidChange:(index - 1)];
		[tableView deselectRowAtIndexPath:indexPath animated:NO];
		[tableView reloadData];
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
		{
			return UITableViewCellEditingStyleNone;
		}
		else
		{
			return UITableViewCellEditingStyleDelete;
		}
	}	
}

// Manage deletion of a protein from disk
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath 
{
	NSInteger index = [indexPath row];
	if ([SLSMoleculeAppDelegate isRunningOniPad])
	{
		index++;
	}
	
	if (index == 0) // Can't delete the Download new molecules item
	{
		return;
	}
    // If row is deleted, remove it from the list.
    if (editingStyle == UITableViewCellEditingStyleDelete) 
	{
		[[molecules objectAtIndex:(index - 1)] deleteMolecule];
		[molecules removeObjectAtIndex:(index - 1)];
		if ( (index - 1) == selectedIndex )
		{
			if ([molecules count] < 1)
			{
				[self.delegate selectedMoleculeDidChange:0];
			}
			else
			{
				selectedIndex = 0;
				[self.delegate selectedMoleculeDidChange:0];
			}
		}
		else if ( (index - 1) < selectedIndex )
		{
			selectedIndex--;
		}
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
		[tableView reloadData];
    }
}

- (void)didReceiveMemoryWarning
{
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    // Overriden to allow any orientation.
    return YES;
}

#pragma mark -
#pragma mark Accessors

@synthesize delegate;
@synthesize database;
@synthesize molecules;
@synthesize selectedIndex;

@end
