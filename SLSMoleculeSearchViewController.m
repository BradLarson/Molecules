//
//  SLSMoleculeSearchViewController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 7/22/2008.
//
//  This handles the keyword searching functionality of the Protein Data Bank

#import "SLSMoleculeSearchViewController.h"
#import "SLSMoleculeDownloadViewController.h"
#import "VCTitleCase.h"

#define MAX_SEARCH_RESULT_CODES 25

@implementation SLSMoleculeSearchViewController

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithStyle:(UITableViewStyle)style 
{
	if (self = [super initWithStyle:style]) 
	{
		// Initialize the search bar and title
		
		self.view.frame = [[UIScreen mainScreen] applicationFrame];
		self.view.autoresizesSubviews = YES;

		keywordSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 44.0f)];
		keywordSearchBar.placeholder = NSLocalizedStringFromTable(@"Search for molecules", @"Localized", nil);
		keywordSearchBar.delegate = self;
		keywordSearchBar.autocorrectionType = UITextAutocorrectionTypeNo;
		[keywordSearchBar becomeFirstResponder];
				
		self.navigationItem.title = NSLocalizedStringFromTable(@"Protein Data Bank", @"Localized", nil);
		self.navigationItem.rightBarButtonItem = nil;

		self.tableView.tableHeaderView = keywordSearchBar;
		
		downloadedFileContents = nil;
		searchResultTitles = nil;
		searchResultPDBCodes = nil;
		searchResultRetrievalConnection = nil;
		nextResultsRetrievalConnection = nil;
		searchCancelled = NO;
		currentPageOfResults = 0;
	}
	return self;
}

- (void)dealloc 
{
	[keywordSearchBar release];
	[searchResultRetrievalConnection release];
	[searchResultTitles release];
	[searchResultPDBCodes release];
	[downloadedFileContents release];
	[super dealloc];
}

#pragma mark -
#pragma mark Performing search

- (BOOL)performSearchWithKeyword:(NSString *)keyword;
{
	// Clear the old search results table
	[searchResultTitles release];
	searchResultTitles = nil;
	
	[searchResultPDBCodes release];
	searchResultPDBCodes = nil;
	
	NSString *pdbSearchURL = [[NSString alloc] initWithFormat:@"http://www.rcsb.org/pdb/search/navbarsearch.do?newSearch=yes&isAuthorSearch=no&radioset=All&inputQuickSearch=%@&outformat=text&resultsperpage=%d", keyword, MAX_SEARCH_RESULT_CODES];
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	
	NSURLRequest *pdbSearchRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:pdbSearchURL]
													cachePolicy:NSURLRequestUseProtocolCachePolicy
												timeoutInterval:60.0];
	[pdbSearchURL release];
	searchResultRetrievalConnection = [[NSURLConnection alloc] initWithRequest:pdbSearchRequest delegate:self];
	
	downloadedFileContents = [[NSMutableData data] retain];
	
	if (searchResultRetrievalConnection) 
	{
		[self.tableView reloadData];
	} 
	else 
	{
		return NO;
	}
	return YES;
}

- (void)processSearchResultsAppendingNewData:(BOOL)appendData;
{
	if (!appendData)
	{
		[searchResultRetrievalConnection release];
		searchResultRetrievalConnection = nil;

		searchResultTitles = [[NSMutableArray alloc] init];
		searchResultPDBCodes = [[NSMutableArray alloc] init];
	}
	else
	{
		[nextResultsRetrievalConnection release];
		nextResultsRetrievalConnection = nil;
	}	

	NSString *titlesAndPDBCodeString = [[NSString alloc] initWithData:downloadedFileContents encoding:NSASCIIStringEncoding];
	[downloadedFileContents release];
	downloadedFileContents = nil;

	if ([[[titlesAndPDBCodeString substringToIndex:5] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""])
	{
		// No results match this query
		currentPageOfResults = 1;
		[titlesAndPDBCodeString release];
		[self.tableView reloadData];		
		return;
	}

	NSUInteger length = [titlesAndPDBCodeString length];
	NSUInteger lineStart = 0, lineEnd = 0, contentsEnd = 0;
	NSRange currentRange;
	
	while (lineEnd < length) 
	{
//		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

		[titlesAndPDBCodeString getParagraphStart:&lineStart end:&lineEnd contentsEnd:&contentsEnd forRange:NSMakeRange(lineEnd, 0)];
		currentRange = NSMakeRange(lineStart, contentsEnd - lineStart);
		NSString *currentLine = [titlesAndPDBCodeString substringWithRange:currentRange];
		
		
		NSArray *lineComponents = [currentLine componentsSeparatedByString:@"\t"];
		if ([lineComponents count] > 1)
		{
			NSString *pdbCode = [lineComponents objectAtIndex:0];
			NSString *moleculeTitle = [lineComponents objectAtIndex:1];
			if ((pdbCode != nil) && (moleculeTitle != nil))
			{
				[searchResultTitles addObject:moleculeTitle];
				[searchResultPDBCodes addObject:pdbCode];
			}
		}
		
//		[pool release];
	}		
	
	currentPageOfResults = 1;
	[titlesAndPDBCodeString release];
	[self.tableView reloadData];
}

- (BOOL)grabNextSetOfSearchResults;
{
	currentPageOfResults++;
	NSString *nextResultsURL = [[NSString alloc] initWithFormat:@"http://www.rcsb.org/pdb/results/results.do?outformat=text&gotopage=%d", currentPageOfResults];
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	
	NSURLRequest *pdbSearchRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:nextResultsURL]
													cachePolicy:NSURLRequestUseProtocolCachePolicy
												timeoutInterval:60.0];
	[nextResultsURL release];
	nextResultsRetrievalConnection = [[NSURLConnection alloc] initWithRequest:pdbSearchRequest delegate:self];
	
	downloadedFileContents = [[NSMutableData data] retain];
	
	if (nextResultsRetrievalConnection) 
	{
		[self.tableView reloadData];
	} 
	else 
	{
		return NO;
	}
	return YES;
	
}

#pragma mark -
#pragma mark UITableViewController methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	// Running a search, so display a status cell
	if (searchResultRetrievalConnection != nil)
		return 1;
	else if (searchResultTitles == nil)
		return 0;
	// No results to the last search, so display one cell explaining that
	else if ([searchResultTitles count] == 0)
		return 1;
	else
	{
		return [searchResultTitles count] + 1;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 60.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{	
	UITableViewCell *cell;
	// Running a search, so display a status cell
	if ((searchResultRetrievalConnection != nil) || ((nextResultsRetrievalConnection != nil) && (indexPath.row >= [searchResultTitles count])))
	{
		cell = [tableView dequeueReusableCellWithIdentifier:@"SearchInProgress"];
		if (cell == nil) 
		{		
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"SearchInProgress"] autorelease];
			cell.textLabel.textColor = [UIColor blackColor];
			cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];
			
			//		CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 250.0, 5.0, 240.0, 32.0);
//			CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 70.0, 14.0, 32.0, 32.0);
			CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 70.0f, 20.0f, 20.0f, 20.0f);
			UIActivityIndicatorView *spinningIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			[spinningIndicator startAnimating];
			spinningIndicator.frame = frame;
			[cell.contentView addSubview:spinningIndicator];
			[spinningIndicator release];
			cell.accessoryType = UITableViewCellAccessoryNone;
			cell.textLabel.font = [UIFont systemFontOfSize:16.0];
			cell.textLabel.textAlignment = UITextAlignmentCenter;
		}
		cell.textLabel.text = NSLocalizedStringFromTable(@"Searching...", @"Localized", nil);
	}
	else if (searchResultTitles == nil)
		cell = nil;
	// No results to the last search, so display one cell explaining that
	else if ([searchResultTitles count] == 0)
	{
		cell = [tableView dequeueReusableCellWithIdentifier:@"NoResults"];
		if (cell == nil) 
		{		
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"NoResults"] autorelease];
			cell.textLabel.textColor = [UIColor blackColor];
			cell.textLabel.font = [UIFont systemFontOfSize:16.0];
			cell.textLabel.text = NSLocalizedStringFromTable(@"No results", @"Localized", nil);
			cell.textLabel.textAlignment = UITextAlignmentCenter;
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
	}
	else
	{
		if ([indexPath row] >= [searchResultTitles count])
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"LoadMore"];
			if (cell == nil) 
			{		
				cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"LoadMore"] autorelease];
				cell.textLabel.textColor = [UIColor blackColor];
				cell.textLabel.font = [UIFont systemFontOfSize:16.0];
				cell.textLabel.textAlignment = UITextAlignmentCenter;
				cell.textLabel.text = NSLocalizedStringFromTable(@"Load next 25 results", @"Localized", nil);
				cell.accessoryType = UITableViewCellAccessoryNone;
				cell.detailTextLabel.text = @"";
			}
		}
		else
		{
			cell = [tableView dequeueReusableCellWithIdentifier:NSLocalizedStringFromTable(@"Results", @"Localized", nil)];
			if (cell == nil) 
			{		
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:NSLocalizedStringFromTable(@"Results", @"Localized", nil)] autorelease];
				cell.textLabel.textColor = [UIColor blackColor];
				cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];
				cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:12.0];
			}

			cell.textLabel.text = [searchResultTitles objectAtIndex:[indexPath row]];
			cell.detailTextLabel.text = [searchResultPDBCodes objectAtIndex:[indexPath row]];
			
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
	}

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	// Prevent any crashes by clicking on a non-normal cell
	if (searchResultRetrievalConnection != nil)
		return;
	else if (searchResultTitles == nil)
		return;
	// No results to the last search, so display one cell explaining that
	else if ([searchResultTitles count] == 0)
		return;	
	
	
	if (indexPath.row >= [searchResultTitles count])
	{
		[self grabNextSetOfSearchResults];
	}
	else
	{
		NSString *selectedTitle = [searchResultTitles objectAtIndex:[indexPath row]];
		NSString *selectedPDBCode = [searchResultPDBCodes objectAtIndex:[indexPath row]];
		
		SLSMoleculeDownloadViewController *downloadViewController = [[SLSMoleculeDownloadViewController alloc] initWithPDBCode:selectedPDBCode andTitle:selectedTitle];
		downloadViewController.delegate = self;
		
		[self.navigationController pushViewController:downloadViewController animated:YES];
		[downloadViewController release];	
	}	
}

- (void)didReceiveMemoryWarning 
{
}

#pragma mark -
#pragma mark UIViewController methods

- (void)viewWillDisappear:(BOOL)animated
{
	keywordSearchBar.delegate = self;
	
	[super viewWillDisappear:animated];
}

#pragma mark -
#pragma mark UISearchBarDelegate methods

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;
{
	// Hide the keyboard once search has been initiated
	[searchBar resignFirstResponder];
	[self performSearchWithKeyword:searchBar.text];
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Connection failed", @"Localized", nil) message:NSLocalizedStringFromTable(@"Could not connect to the Protein Data Bank", @"Localized", nil)
												   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
	[alert show];
	[alert release];
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

	[downloadedFileContents release];
	downloadedFileContents = nil;
	
	[searchResultRetrievalConnection release];
	searchResultRetrievalConnection = nil;
	
	[nextResultsRetrievalConnection release];
	nextResultsRetrievalConnection = nil;
	
	[self.tableView reloadData];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
{
	// Concatenate the new data with the existing data to build up the downloaded file
	// Update the status of the download
	
	[downloadedFileContents appendData:data];

	if (searchCancelled)
	{
		[connection cancel];
		[downloadedFileContents release];
		downloadedFileContents = nil;
		
		// Release connection?
		[self.tableView reloadData];
		
		searchCancelled = NO;
		return;
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
{
	// TODO: Deal with a 404 error by checking filetype header
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

	if (connection == searchResultRetrievalConnection)
		[self processSearchResultsAppendingNewData:NO];
	else
		[self processSearchResultsAppendingNewData:YES];
}

#pragma mark -
#pragma mark MoleculeDownloadDelegate protocol method

- (void)moleculeDownloadController:(SLSMoleculeDownloadViewController *)moleculeDownloadViewController didAddMolecule:(NSData *)moleculeData withFilename:(NSString *)filename;
{
	[self.delegate moleculeDownloadController:moleculeDownloadViewController didAddMolecule:moleculeData withFilename:filename];
}

#pragma mark -
#pragma mark Accessors

@synthesize delegate;

@end

