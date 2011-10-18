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
#import "SLSMoleculeDownloadController.h"
#import "SLSMoleculeTableViewController.h"
#import "VCTitleCase.h"
#import "SLSMoleculeAppDelegate.h"
#import "SLSMoleculeWebDetailViewController.h"

#define MAX_SEARCH_RESULT_CODES 10

@implementation SLSMoleculeSearchViewController

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithStyle:(UITableViewStyle)style 
{
	if ((self = [super initWithStyle:style])) 
	{
		// Initialize the search bar and title
		
		self.view.frame = [[UIScreen mainScreen] applicationFrame];
		self.view.autoresizesSubviews = YES;

		keywordSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 44.0f)];
		keywordSearchBar.placeholder = NSLocalizedStringFromTable(@"Search PubChem", @"Localized", nil);
		keywordSearchBar.delegate = self;
		keywordSearchBar.autocorrectionType = UITextAutocorrectionTypeNo;
        keywordSearchBar.scopeButtonTitles = [NSArray arrayWithObjects:@"PubChem", @"Protein Data Bank", nil];
        keywordSearchBar.showsScopeBar = YES;
        [keywordSearchBar sizeToFit];
        
        currentSearchType = PUBCHEMSEARCH;
        
//        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
//        {
//            keywordSearchBar.barStyle = UIBarStyleBlack;
//        }
		[keywordSearchBar becomeFirstResponder];
				
		self.navigationItem.title = NSLocalizedStringFromTable(@"Search For Molecules", @"Localized", nil);
		self.navigationItem.rightBarButtonItem = nil;

		self.tableView.tableHeaderView = keywordSearchBar;
		
		downloadedFileContents = nil;
		searchResultTitles = nil;
		searchResultIDs = nil;
		searchResultRetrievalConnection = nil;
		nextResultsRetrievalConnection = nil;
		searchCancelled = NO;
		currentPageOfResults = 0;
		
		if ([SLSMoleculeAppDelegate isRunningOniPad])
		{
			self.contentSizeForViewInPopover = CGSizeMake(320.0, 700.0);
		}
		
	}
	return self;
}

- (void)viewDidLoad;
{
	[super viewDidLoad];
    
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
//		//		self.tableView.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.054f alpha:1.0f];
//		self.tableView.backgroundColor = [UIColor blackColor];
//        self.tableView.separatorColor = [UIColor clearColor];
//        self.tableView.rowHeight = 50.0;

		self.tableView.backgroundColor = [UIColor whiteColor];
//        CAGradientLayer *shadowGradient = [SLSMoleculeTableViewController shadowGradientForSize:CGSizeMake(320.0f, self.navigationController.view.frame.size.height)];
//		[self.navigationController.view.layer setMask:shadowGradient];
//		self.navigationController.view.layer.masksToBounds = NO;
	}
	else
	{
		self.tableView.backgroundColor = [UIColor whiteColor];
	}	
}

- (void)dealloc 
{
    downloadController = nil;
    
    currentXMLElementString = nil;

}

#pragma mark -
#pragma mark Performing search

- (BOOL)performSearchWithKeyword:(NSString *)keyword;
{
	// Clear the old search results table
	searchResultTitles = nil;
	
	searchResultIDs = nil;
    
    searchResultIUPACNames = nil;

	NSString *searchURL = nil;
    
    if (currentSearchType == PROTEINDATABANKSEARCH)
    {
        searchURL = [[NSString alloc] initWithFormat:@"http://www.rcsb.org/pdb/search/navbarsearch.do?newSearch=yes&isAuthorSearch=no&radioset=All&inputQuickSearch=%@&outformat=text&resultsperpage=%d", [keyword stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], MAX_SEARCH_RESULT_CODES];
    }
    else
    {
        //http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pccompound&retmax=10&term=benzene
        isRetrievingCompoundNames = NO;
        
        NSString *keywordWithFilter = [keyword stringByAppendingString:@" \"has 3d conformer\"[Filter]"];
        searchURL = [[NSString alloc] initWithFormat:@"http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pccompound&retmax=%d&term=%@", MAX_SEARCH_RESULT_CODES, [keywordWithFilter stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	
	NSURLRequest *pdbSearchRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:searchURL]
													cachePolicy:NSURLRequestUseProtocolCachePolicy
												timeoutInterval:60.0];
	searchResultRetrievalConnection = [[NSURLConnection alloc] initWithRequest:pdbSearchRequest delegate:self];
	
	downloadedFileContents = [NSMutableData data];
	
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
		searchResultRetrievalConnection = nil;

		searchResultTitles = [[NSMutableArray alloc] init];
		searchResultIDs = [[NSMutableArray alloc] init];
	}
	else
	{
		nextResultsRetrievalConnection = nil;
	}	
    
    if (currentSearchType == PROTEINDATABANKSEARCH)
    {
        [self processPDBSearchResults];
    }
    else
    {
        [self processPubChemKeywordSearch];
    }

	[self.tableView reloadData];
}

- (void)processPDBSearchResults;
{
    NSString *titlesAndPDBCodeString = [[NSString alloc] initWithData:downloadedFileContents encoding:NSASCIIStringEncoding];
	downloadedFileContents = nil;
	
	NSRange locationOfHTMLTag = [titlesAndPDBCodeString rangeOfString:@"<html"];
	if (locationOfHTMLTag.location != NSNotFound)
	{
		// Single result, so parse out title from the HTML returned and try to determine the four character code
		NSRange locationOfPDBCode = [titlesAndPDBCodeString rangeOfString:@"structureId="];
		if (locationOfPDBCode.location == NSNotFound)
		{
			// No results match this query
			currentPageOfResults = 1;
			[self.tableView reloadData];		
			return;
		}
		
		NSString *pdbCode = [titlesAndPDBCodeString substringWithRange:NSMakeRange(locationOfPDBCode.location + locationOfPDBCode.length, 4)];
        
		NSString *titleString = nil;
		NSRange locationOfTitleStart = [titlesAndPDBCodeString rangeOfString:@"<title>"];
		NSRange locationOfTitleEnd = [titlesAndPDBCodeString rangeOfString:@"</title>"];
		if ( (locationOfTitleStart.location == NSNotFound) || (locationOfTitleEnd.location == NSNotFound) )
		{
			titleString = pdbCode;
		}
		else
		{
            //			<title>RCSB Protein Data Bank - Structure Summary  for 1BNA - STRUCTURE OF A B-DNA DODECAMER. CONFORMATION AND DYNAMICS</title>
            
			titleString = [titlesAndPDBCodeString substringWithRange:NSMakeRange(locationOfTitleStart.location + locationOfTitleStart.length, locationOfTitleEnd.location - (locationOfTitleStart.location + locationOfTitleStart.length))];
			NSRange beginningOfActualTitle = [titleString rangeOfString:pdbCode];
			if (beginningOfActualTitle.location != NSNotFound)
			{
				titleString = [titleString substringFromIndex:beginningOfActualTitle.location + 7];
			}
			
		}
        
		[searchResultTitles addObject:titleString];
		[searchResultIDs addObject:pdbCode];
	}
	else
	{
		// Normal search result, so process as expected
		if ([[[titlesAndPDBCodeString substringToIndex:5] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""])
		{
			// No results match this query
			currentPageOfResults = 1;
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
					[searchResultIDs addObject:pdbCode];
				}
			}
			
			//		[pool release];
		}		
	}	
	
	currentPageOfResults = 1;
}

- (void)processPubChemKeywordSearch;
{    
    currentXMLElementString = nil;
    
	searchResultsParser = [[NSXMLParser alloc] initWithData:downloadedFileContents];
	downloadedFileContents = nil;

    searchResultsParser.delegate = self;
    [searchResultsParser setShouldResolveExternalEntities:YES];
    [searchResultsParser parse];
}

- (void)retrievePubChemCompoundTitles;
{
    NSMutableString *compoundIDList = [[NSMutableString alloc] init];
    
    BOOL isFirstID = YES;
    for (NSString *currentCompoundID in searchResultIDs)
    {
        if (!isFirstID)
        {
            [compoundIDList appendFormat:@",%@", currentCompoundID];
        }
        else
        {
            [compoundIDList appendString:currentCompoundID];
            isFirstID = NO;
        }
    }
    
        //http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pccompound&retmax=10&term=benzene
    isRetrievingCompoundNames = YES;
    NSString *searchURL = [[NSString alloc] initWithFormat:@"http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pccompound&id=%@", compoundIDList];
    
    
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	
	NSURLRequest *sdfSearchRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:searchURL]
													cachePolicy:NSURLRequestUseProtocolCachePolicy
												timeoutInterval:60.0];
	searchResultRetrievalConnection = [[NSURLConnection alloc] initWithRequest:sdfSearchRequest delegate:self];
	
	downloadedFileContents = [NSMutableData data];
	
	if (!searchResultRetrievalConnection) 
	{
        // TODO: Some sort of error handling
	} 
}

- (void)processPubChemCompoundTitles;
{
    
    searchResultIUPACNames = [[NSMutableArray alloc] init];

    searchResultRetrievalConnection = nil;

    currentXMLElementString = nil;
    
	searchResultsParser = [[NSXMLParser alloc] initWithData:downloadedFileContents];
	downloadedFileContents = nil;
    
    searchResultsParser.delegate = self;
    [searchResultsParser setShouldResolveExternalEntities:YES];
    [searchResultsParser parse];
}

- (BOOL)grabNextSetOfSearchResults;
{
	currentPageOfResults++;
	NSString *nextResultsURL = [[NSString alloc] initWithFormat:@"http://www.rcsb.org/pdb/results/results.do?outformat=text&gotopage=%d", currentPageOfResults];
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	
	NSURLRequest *pdbSearchRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:nextResultsURL]
													cachePolicy:NSURLRequestUseProtocolCachePolicy
												timeoutInterval:60.0];
	nextResultsRetrievalConnection = [[NSURLConnection alloc] initWithRequest:pdbSearchRequest delegate:self];
	
	downloadedFileContents = [NSMutableData data];
	
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
        if (currentSearchType == PROTEINDATABANKSEARCH)
        {
            return [searchResultTitles count] + 1;
        }
        else
        {
            return [searchResultTitles count];
        }
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
//			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"SearchInProgress"] autorelease];
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SearchInProgress"];
            
//            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
//            {
//                cell.backgroundColor = [UIColor blackColor];
//                cell.textLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
//            }
//            else
//            {
                cell.textLabel.textColor = [UIColor blackColor];
//            }

			cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];
			
			//		CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 250.0, 5.0, 240.0, 32.0);
//			CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 70.0, 14.0, 32.0, 32.0);
			CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 70.0f, 20.0f, 20.0f, 20.0f);
			UIActivityIndicatorView *spinningIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			[spinningIndicator startAnimating];
			spinningIndicator.frame = frame;
			[cell.contentView addSubview:spinningIndicator];
			cell.accessoryType = UITableViewCellAccessoryNone;
			cell.textLabel.font = [UIFont systemFontOfSize:16.0];
			cell.textLabel.textAlignment = UITextAlignmentCenter;
		}
		cell.textLabel.text = NSLocalizedStringFromTable(@"Searching...", @"Localized", nil);
	}
	else if (searchResultTitles == nil)
    {
		cell = nil;
    }
	// No results to the last search, so display one cell explaining that
	else if ([searchResultTitles count] == 0)
	{
		cell = [tableView dequeueReusableCellWithIdentifier:@"NoResults"];
		if (cell == nil) 
		{		
//			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"NoResults"] autorelease];
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"NoResults"];

//            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
//            {
//                cell.backgroundColor = [UIColor blackColor];
//                cell.textLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
//            }
//            else
//            {
                cell.textLabel.textColor = [UIColor blackColor];
//            }

			cell.textLabel.font = [UIFont systemFontOfSize:16.0];
			cell.textLabel.text = NSLocalizedStringFromTable(@"No results", @"Localized", nil);
			cell.textLabel.textAlignment = UITextAlignmentCenter;
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
	}
    else if ((isDownloading) && ([indexPath row] == indexOfDownloadingMolecule))
    {
        cell = [tableView dequeueReusableCellWithIdentifier:@"DownloadInProgress"];
		if (cell == nil) 
		{		
            
//            cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"DownloadInProgress"] autorelease];
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DownloadInProgress"];

//            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
//            {
//                cell.backgroundColor = [UIColor blackColor];
//                cell.textLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
//            }
//            else
//            {
                cell.textLabel.textColor = [UIColor blackColor];
//            }
            
            cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];
            
            //		CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 250.0, 5.0, 240.0, 32.0);
            //			CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 70.0, 14.0, 32.0, 32.0);
            CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 70.0f, 20.0f, 20.0f, 20.0f);
            UIActivityIndicatorView *spinningIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            [spinningIndicator startAnimating];
            spinningIndicator.frame = frame;
            [cell.contentView addSubview:spinningIndicator];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.font = [UIFont systemFontOfSize:16.0];
            cell.textLabel.textAlignment = UITextAlignmentCenter;
        }
        cell.textLabel.text = NSLocalizedStringFromTable(@"Downloading...", @"Localized", nil);        
    }
	else
	{
		if ([indexPath row] >= [searchResultTitles count])
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"LoadMore"];
			if (cell == nil) 
			{		
//				cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"LoadMore"] autorelease];
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LoadMore"];

//                if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
//                {
//                    cell.backgroundColor = [UIColor blackColor];
//                    cell.textLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
//                }
//                else
//                {
                    cell.textLabel.textColor = [UIColor blackColor];
//                }
                
				cell.textLabel.font = [UIFont systemFontOfSize:16.0];
				cell.textLabel.textAlignment = UITextAlignmentCenter;
				cell.textLabel.text = NSLocalizedStringFromTable(@"Load next 10 results", @"Localized", nil);
				cell.accessoryType = UITableViewCellAccessoryNone;
				cell.detailTextLabel.text = @"";
			}
		}
		else
		{
			cell = [tableView dequeueReusableCellWithIdentifier:NSLocalizedStringFromTable(@"Results", @"Localized", nil)];
			if (cell == nil) 
			{		
				cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:NSLocalizedStringFromTable(@"Results", @"Localized", nil)];

//                if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
//                {
//                    cell.backgroundColor = [UIColor blackColor];
//                    cell.textLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
//                    CAGradientLayer *glowGradientLayer = [SLSMoleculeTableViewController glowGradientForSize:CGSizeMake(self.view.frame.size.width, 60.0)];
//                    
//                    [cell.layer insertSublayer:glowGradientLayer atIndex:10];
//                }
//                else
//                {
                    cell.textLabel.textColor = [UIColor blackColor];
//                }
                cell.selectionStyle = UITableViewCellSelectionStyleNone;

				cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
                cell.textLabel.numberOfLines = 2;
				cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:14.0];

//                cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];
//				cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:12.0];
            }

            if ((isDownloading) && ([indexPath row] != indexOfDownloadingMolecule))
            {
//                cell.contentView.backgroundColor = [UIColor colorWithWhite:0.6 alpha:1.0];
                cell.textLabel.textColor = [UIColor colorWithWhite:0.3 alpha:1.0];
                cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.2 alpha:1.0];
            }
            
			cell.textLabel.text = [searchResultTitles objectAtIndex:[indexPath row]];
            if (currentSearchType == PROTEINDATABANKSEARCH)
            {
                cell.detailTextLabel.text = [searchResultIDs objectAtIndex:[indexPath row]];
            }
            else
            {
                cell.detailTextLabel.text = [searchResultIUPACNames objectAtIndex:[indexPath row]];
            }
			
            cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
		}
	}

	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath 
{
    if ((isDownloading) && ([indexPath row] != indexOfDownloadingMolecule))
    {
        cell.backgroundColor = [UIColor colorWithWhite:0.4 alpha:1.0];
    }
    else
    {
        cell.backgroundColor = [UIColor whiteColor];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	// Prevent any crashes by clicking on a non-normal cell
	if (searchResultRetrievalConnection != nil)
    {
		return;
    }
	else if (searchResultTitles == nil)
    {
		return;
    }
	// No results to the last search, so display one cell explaining that
	else if ([searchResultTitles count] == 0)
    {        
		return;
    }
    else if (isDownloading)
    {
        return;
    }
		
	if (indexPath.row >= [searchResultTitles count])
	{
		[self grabNextSetOfSearchResults];
	}
	else
	{
        indexOfDownloadingMolecule = indexPath.row;
        isDownloading = YES;
        self.tableView.backgroundColor = [UIColor colorWithWhite:0.4 alpha:1.0];
        self.tableView.separatorColor = [UIColor colorWithWhite:0.4 alpha:1.0];

        [self.tableView reloadData];

		NSString *selectedTitle = [searchResultTitles objectAtIndex:[indexPath row]];
		NSString *selectedID = [searchResultIDs objectAtIndex:[indexPath row]];

        downloadController = [[SLSMoleculeDownloadController alloc] initWithID:selectedID title:selectedTitle searchType:currentSearchType];
        
        [downloadController downloadNewMolecule];
//		
//		SLSMoleculeDownloadViewController *downloadViewController = [[SLSMoleculeDownloadViewController alloc] initWithPDBCode:selectedPDBCode andTitle:selectedTitle];
//		
//		[self.navigationController pushViewController:downloadViewController animated:YES];
//		[downloadViewController release];	
	}	
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
//	NSInteger index = [indexPath row];

    NSString *selectedID = [searchResultIDs objectAtIndex:[indexPath row]];
    NSString *webDetailAddress = nil;
    
    if (currentSearchType == PROTEINDATABANKSEARCH)
    {
        webDetailAddress = [NSString stringWithFormat:@"http://www.rcsb.org/pdb/explore/explore.do?structureId=%@", selectedID];
    }
    else
    {
        webDetailAddress = [NSString stringWithFormat:@"http://pubchem.ncbi.nlm.nih.gov/summary/summary.cgi?cid=%@", selectedID];
    }
    
    SLSMoleculeWebDetailViewController *detailViewController = [[SLSMoleculeWebDetailViewController alloc] initWithURL:[NSURL URLWithString:webDetailAddress]];
    
    [self.navigationController pushViewController:detailViewController animated:YES];
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overriden to allow any orientation.
    return YES;
}

#pragma mark -
#pragma mark UISearchBarDelegate methods

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;
{
	// Hide the keyboard once search has been initiated
	[searchBar resignFirstResponder];
	[self performSearchWithKeyword:searchBar.text];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope
{
	searchResultTitles = nil;
	
	searchResultIDs = nil;

    switch (selectedScope)
    {
        case PUBCHEMSEARCH: 
        {
            keywordSearchBar.placeholder = NSLocalizedStringFromTable(@"Search PubChem", @"Localized", nil);            
        }; break;
        case PROTEINDATABANKSEARCH:
        default:
        {
            keywordSearchBar.placeholder = NSLocalizedStringFromTable(@"Search RCSB Protein Data Bank", @"Localized", nil);
        }; break;
    }
    
    currentSearchType = selectedScope;
    [self.tableView reloadData];
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
{
    NSString *connectionError = nil;
    if (currentSearchType == PROTEINDATABANKSEARCH)
    {
        connectionError = NSLocalizedStringFromTable(@"Could not connect to the Protein Data Bank", @"Localized", nil);
    }
    else
    {
        connectionError = NSLocalizedStringFromTable(@"Could not connect to PubChem", @"Localized", nil);
    }
    
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Connection failed", @"Localized", nil) message:connectionError
												   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
	[alert show];
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

	downloadedFileContents = nil;
	
	searchResultRetrievalConnection = nil;
	
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

    if (isRetrievingCompoundNames)
    {
        [self processPubChemCompoundTitles];
    }
    else
    {
        if (connection == searchResultRetrievalConnection)
        {
            [self processSearchResultsAppendingNewData:NO];
        }
        else
        {
            [self processSearchResultsAppendingNewData:YES];
        }
    }
}

#pragma mark -
#pragma mark NSXMLParser delegate methods

// Append new characters from within the element to an existing, or newly created, string
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string 
{
    if (currentXMLElementString == nil) 
	{
		currentXMLElementString = [[NSMutableString alloc] init];
    }
    [currentXMLElementString appendString:string];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
    if (isRetrievingCompoundNames)
    {
        if ([elementName isEqualToString:@"Item"])
        {
            NSString *attributeName = [attributeDict valueForKey:@"Name"];

            if ([attributeName isEqualToString:@"IUPACName"])
            {
                insideIUPACName = YES;
            }
            else if ([attributeName isEqualToString:@"SynonymList"])
            {
                insideSynonym = YES;
            }
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
{
    if (!isRetrievingCompoundNames)
    {
        if ([elementName isEqualToString:@"Id"])
        {
            // Last item is nil, check for that
            if (currentXMLElementString != nil)
            {
                NSString *trimmedID = [currentXMLElementString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                [searchResultIDs addObject:trimmedID];
            }
        }
    }
    else
    {
        if (insideIUPACName)
        {
            NSString *trimmedIUPACName = [currentXMLElementString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            [searchResultIUPACNames addObject:trimmedIUPACName];
            insideIUPACName = NO;
        }
        else if (insideSynonym)
        {
            NSString *tweakedSynonym = [[currentXMLElementString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] titlecaseString];
            [searchResultTitles addObject:tweakedSynonym];            

            insideSynonym = NO;
        }
    }
	
    currentXMLElementString = nil;
}

- (void)parserDidEndDocument:(NSXMLParser *)parser;
{
//	[self finishParsingXML];
    if (!isRetrievingCompoundNames)
    {
        [self retrievePubChemCompoundTitles];
    }
    else
    {
        [self.tableView reloadData];
        isRetrievingCompoundNames = NO;
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{

}

#pragma mark -
#pragma mark Accessors


@end

