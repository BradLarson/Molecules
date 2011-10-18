//
//  SLSMoleculeDetailViewController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 7/5/2008.
//
//  This controller manages the detail view of the molecule's properties, such as author, publication, etc.

#import "SLSMoleculeDetailViewController.h"
#import "SLSMolecule.h"
#import "SLSTextViewController.h"
#import "SLSMoleculeAppDelegate.h"

#define DESCRIPTION_SECTION 0
#define AUTHOR_SECTION 1
#define STATISTICS_SECTION 2
#define JOURNAL_SECTION 3
#define SOURCE_SECTION 4
#define SEQUENCE_SECTION 5

@implementation SLSMoleculeDetailViewController


- (id)initWithStyle:(UITableViewStyle)style andMolecule:(SLSMolecule *)newMolecule;
{
	if ((self = [super initWithStyle:style])) 
	{
		self.view.frame = [[UIScreen mainScreen] applicationFrame];
		self.view.autoresizesSubviews = YES;
		self.molecule = newMolecule;
		[newMolecule readMetadataFromDatabaseIfNecessary];
		self.title = molecule.compound;

//		UILabel *label= [[UILabel alloc] initWithFrame:CGRectMake(25.0f, 60.0f, 320.0f, 66.0f)];
		UILabel *label= [[UILabel alloc] initWithFrame:CGRectMake(45.0f, 60.0f, 320.0f, 66.0f)];
		label.textColor = [UIColor blackColor];
		label.font = [UIFont fontWithName:@"Helvetica" size:18.0];
		label.backgroundColor = [UIColor groupTableViewBackgroundColor];	
		label.text = molecule.compound;
		label.numberOfLines = 3;
		label.lineBreakMode = UILineBreakModeWordWrap;
		label.textAlignment = UITextAlignmentCenter;
		//	label.text = @"Text";
		
		self.tableView.tableHeaderView = label;
		
		if ([SLSMoleculeAppDelegate isRunningOniPad])
		{
			self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
		}		
	}
	return self;
}


- (void)viewDidLoad 
{
//	UILabel *label= [[UILabel alloc] initWithFrame:CGRectZero];
	[super viewDidLoad];
}


- (void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated 
{
	[super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated 
{
}

- (void)viewDidDisappear:(BOOL)animated 
{
}

- (void)didReceiveMemoryWarning {
}

#pragma mark -
#pragma mark UITableView Delegate/Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 6;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section 
{
    switch (section) 
	{
        case DESCRIPTION_SECTION:
            return NSLocalizedStringFromTable(@"Description", @"Localized", nil);
        case STATISTICS_SECTION:
            return NSLocalizedStringFromTable(@"Statistics", @"Localized", nil);
        case JOURNAL_SECTION:
            return NSLocalizedStringFromTable(@"Journal", @"Localized", nil);
        case SOURCE_SECTION:
            return NSLocalizedStringFromTable(@"Source", @"Localized", nil);
        case AUTHOR_SECTION:
            return NSLocalizedStringFromTable(@"Author(s)", @"Localized", nil);
        case SEQUENCE_SECTION:
            return NSLocalizedStringFromTable(@"Sequence", @"Localized", nil);
		default:
			break;
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	NSInteger rows = 0;
	
	switch (section) 
	{
		case DESCRIPTION_SECTION:
		case AUTHOR_SECTION:
		case SOURCE_SECTION:
		case SEQUENCE_SECTION:
			rows = 1;
			break;
		case STATISTICS_SECTION:
			rows = 4;
			break;
        case JOURNAL_SECTION:
            rows = 3;
            break;
		default:
			break;
	}
	return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if (indexPath.section == STATISTICS_SECTION) 
	{
		static NSString *StatisticsCellIdentifier = @"StatisticsCell";
		
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:StatisticsCellIdentifier];
		if (cell == nil) 
		{
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:StatisticsCellIdentifier];
			
			cell.detailTextLabel.textColor = [UIColor colorWithRed:50.0f/255.0f green:79.0f/255.0f blue:133.0f/255.0f alpha:1.0f];
            cell.detailTextLabel.highlightedTextColor = [UIColor whiteColor];			
		}
		
		switch (indexPath.row)
		{
			case 0:
			{
				cell.textLabel.text = NSLocalizedStringFromTable(@"File name", @"Localized", nil);
				cell.detailTextLabel.text = molecule.filename;
			}; break;
			case 1:
			{
				cell.textLabel.text = NSLocalizedStringFromTable(@"Number of atoms", @"Localized", nil);
				cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", molecule.numberOfAtoms];
			}; break;
			case 2:
			{
				cell.textLabel.text =NSLocalizedStringFromTable(@"Number of structures", @"Localized", nil);
				cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", molecule.numberOfStructures];
			}; break;
			case 3:
			{
				cell.textLabel.text = NSLocalizedStringFromTable(@"Current structure", @"Localized", nil);
				cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", molecule.numberOfStructureBeingDisplayed];
			}; break;
		}
		return cell;
	}

	static NSString *MyIdentifier = @"MyIdentifier";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil) {
//		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:MyIdentifier] autorelease];
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MyIdentifier];
	}
	cell.textLabel.text = [self textForIndexPath:indexPath];
	
	
//	static NSString *DetailedTextCell = @"DetailedTextCell";
//
//	CellTextView *cell = (CellTextView *)[tableView dequeueReusableCellWithIdentifier:DetailedTextCell];
//
//	if (cell == nil)
//	{
//		cell = [[[CellTextView alloc] initWithFrame:CGRectZero reuseIdentifier:DetailedTextCell] autorelease];
//	}
//
//	cell.view = [self createLabelForIndexPath:indexPath];
	return cell;
}

- (UILabel *)createLabelForIndexPath:(NSIndexPath *)indexPath;
{
	NSString *text = nil;
    switch (indexPath.section) 
	{
		case DESCRIPTION_SECTION: // type -- should be selectable -> checkbox
			text = molecule.title;
			break;
		case AUTHOR_SECTION: // instructions
			text = molecule.author;
			break;
        case JOURNAL_SECTION:
		{
			switch (indexPath.row)
			{
				case 0: text = molecule.journalTitle; break;
				case 1: text = molecule.journalAuthor; break;
				case 2: text = molecule.journalReference; break;
			}
		}; break;
        case SOURCE_SECTION:
			text = molecule.source;
			break;
		case SEQUENCE_SECTION:
			text = molecule.sequence;
			break;
		default:
			break;
	}
    	
//	CGRect frame = CGRectMake(0.0, 0.0, 100.0, 100.0);

	UILabel *label= [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 100.0f, 100.0f)];
    label.textColor = [UIColor blackColor];
//    textView.font = [UIFont fontWithName:@"Helvetica" size:18.0];
//	textView.editable = NO;
    label.backgroundColor = [UIColor whiteColor];
	
	label.text = text;
	
	return label;
}

//#define HEIGHTPERLINE 23.0
//
//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//	CGFloat result;
//
//	switch (indexPath.section) 
//	{
//		case DESCRIPTION_SECTION: // type -- should be selectable -> checkbox
//			result = (float)[molecule.title length] * HEIGHTPERLINE;
//			break;
//		case AUTHOR_SECTION: // instructions
//			result = (float)[molecule.author length] * HEIGHTPERLINE;
//			break;
//        case JOURNAL_SECTION:
//		{
//			switch (indexPath.row)
//			{
//				case 0: result = (float)[molecule.journalTitle length] * HEIGHTPERLINE; break;
//				case 1: result = (float)[molecule.journalAuthor length] * HEIGHTPERLINE; break;
//				case 2: result = (float)[molecule.journalReference length] * HEIGHTPERLINE; break;
//			}
//		}; break;
//        case SOURCE_SECTION:
//			result = (float)[molecule.source length] * HEIGHTPERLINE;
//			break;
//		case SEQUENCE_SECTION:
//			result = (float)[molecule.sequence length] * HEIGHTPERLINE;
//			break;
//		default:
//			result = 43.0;
//			break;
//	}
//	
//	return result;
//}

- (NSString *)textForIndexPath:(NSIndexPath *)indexPath;
{
	NSString *text;
	switch (indexPath.section) 
	{
		case DESCRIPTION_SECTION:
			text = molecule.title;
			break;
		case AUTHOR_SECTION:
			text = molecule.author;
			break;
        case JOURNAL_SECTION:
		{
			switch (indexPath.row)
			{
				case 0: text = molecule.journalTitle; break;
				case 1: text = molecule.journalAuthor; break;
				case 2: text = molecule.journalReference; break;
				default: text = @""; break;
			}
		}; break;
        case SOURCE_SECTION:
			text = molecule.source;
			break;
		case SEQUENCE_SECTION:
			text = molecule.sequence;
			break;
		default:
			text = @"";
			break;
	}
	
	return [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
	
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath;
{
	if (indexPath.section == STATISTICS_SECTION)
		return nil;
	
	return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.section != STATISTICS_SECTION)
	{
		SLSTextViewController *nextViewController = [[SLSTextViewController alloc] initWithTitle:[self tableView:tableView titleForHeaderInSection:indexPath.section] andContent:[self textForIndexPath:indexPath]];
		[self.navigationController pushViewController:nextViewController animated:YES];
	}
	
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overriden to allow any orientation.
    return YES;
}

#pragma mark -
#pragma mark Accessors

@synthesize molecule;

@end

