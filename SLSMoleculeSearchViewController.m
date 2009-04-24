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

#define MAX_SEARCH_RESULT_BYTES 3700 // ~ 50 PDB codes
#define MAX_SEARCH_RESULT_CODES 50   // ~ 50 PDB codes

@implementation SLSMoleculeSearchViewController


- (id)initWithStyle:(UITableViewStyle)style 
{
	if (self = [super initWithStyle:style]) 
	{
		// Initialize the search bar and title
		
		self.view.frame = [[UIScreen mainScreen] applicationFrame];
		self.view.autoresizesSubviews = YES;

		UISearchBar *keywordSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 44.0f)];
		keywordSearchBar.placeholder = NSLocalizedStringFromTable(@"Search for molecules", @"Localized", nil);
		keywordSearchBar.delegate = self;
		keywordSearchBar.autocorrectionType = UITextAutocorrectionTypeNo;
		
		self.navigationItem.title = NSLocalizedStringFromTable(@"Protein Data Bank", @"Localized", nil);
		self.navigationItem.rightBarButtonItem = nil;

		self.tableView.tableHeaderView = keywordSearchBar;
		[keywordSearchBar release];
		
		downloadedFileContents = nil;
		searchResultsParser = nil;
		currentXMLElementString = nil;
		searchResultPDBCodes = nil;
		searchResultTitles = nil;
		dictionaryToAssociatePDBCodesAndTitles = nil;
		pdbCodeRetrievalConnection = nil;
		titleRetrievalConnection = nil;
		searchCancelled = NO;
	}
	return self;
}

- (void)dealloc 
{
	[pdbCodeRetrievalConnection cancel];
	[pdbCodeRetrievalConnection release];
	[titleRetrievalConnection cancel];
	[titleRetrievalConnection release];

	[searchResultPDBCodes release];
	[searchResultTitles release];
	[dictionaryToAssociatePDBCodesAndTitles release];
	[searchResultsParser release];
	[downloadedFileContents release];
	[currentXMLElementString release];
	[super dealloc];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	// Running a search, so display a status cell
	if ( (titleRetrievalConnection != nil) || (pdbCodeRetrievalConnection != nil) )
		return 1;
	else if (searchResultTitles == nil)
		return 0;
	// No results to the last search, so display one cell explaining that
	else if ([searchResultTitles count] == 0)
		return 1;
	else
		return [searchResultTitles count];
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 60.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{	
	UITableViewCell *cell;
	// Running a search, so display a status cell
	if ( (titleRetrievalConnection != nil) || (pdbCodeRetrievalConnection != nil) )
	{
		cell = [tableView dequeueReusableCellWithIdentifier:@"SearchInProgress"];
		if (cell == nil) 
		{		
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"SearchInProgress"] autorelease];
			cell.textColor = [UIColor blackColor];
			cell.font = [UIFont boldSystemFontOfSize:12.0];
			
			//		CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 250.0, 5.0, 240.0, 32.0);
//			CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 70.0, 14.0, 32.0, 32.0);
			CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 70.0f, 20.0f, 20.0f, 20.0f);
			UIActivityIndicatorView *spinningIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			[spinningIndicator startAnimating];
			spinningIndicator.frame = frame;
			[cell.contentView addSubview:spinningIndicator];
			[spinningIndicator release];
			cell.accessoryType = UITableViewCellAccessoryNone;
			cell.font = [UIFont systemFontOfSize:16.0];
		}
		if (titleRetrievalConnection != nil)
			cell.text = NSLocalizedStringFromTable(@"Retrieving titles...", @"Localized", nil);
		else
			cell.text = NSLocalizedStringFromTable(@"Searching...", @"Localized", nil);
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
			cell.textColor = [UIColor blackColor];
			cell.font = [UIFont systemFontOfSize:16.0];
			cell.text = NSLocalizedStringFromTable(@"No results", @"Localized", nil);
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
	}
	else
	{
		cell = [tableView dequeueReusableCellWithIdentifier:NSLocalizedStringFromTable(@"Results", @"Localized", nil)];
		if (cell == nil) 
		{		
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:NSLocalizedStringFromTable(@"Results", @"Localized", nil)] autorelease];
			cell.textColor = [UIColor blackColor];
			cell.font = [UIFont boldSystemFontOfSize:12.0];
			
			//		CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 250.0, 5.0, 240.0, 32.0);
			CGRect frame = CGRectMake(CGRectGetMaxX(cell.contentView.bounds) - 250.0f, 5.0f, 240.0f, 48.0f);
			UILabel *valueLabel = [[UILabel alloc] initWithFrame:frame];
			[valueLabel setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];
			valueLabel.tag = 1;
			valueLabel.textAlignment = UITextAlignmentLeft;
			valueLabel.textColor = [UIColor blackColor];
			valueLabel.font = [UIFont systemFontOfSize:12.0];
			valueLabel.numberOfLines = 3;
			valueLabel.highlightedTextColor = [UIColor whiteColor];
			[cell.contentView addSubview:valueLabel];
			[valueLabel release];
		}
		if (searchResultTitles != nil)
		{	
			NSString *cellTitle = [searchResultTitles objectAtIndex:[indexPath row]];
			cell.text = [dictionaryToAssociatePDBCodesAndTitles objectForKey:cellTitle];
			
			UILabel *valueLabel = (UILabel *)[cell viewWithTag:1];
			valueLabel.text = cellTitle;
			
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		else
		{
			cell.accessoryType = UITableViewCellAccessoryNone;
			cell.text = @"";
		}
	}

	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	// Prevent any crashes by clicking on a non-normal cell
	if ( (titleRetrievalConnection != nil) || (pdbCodeRetrievalConnection != nil) )
		return;
	else if (searchResultTitles == nil)
		return;
	// No results to the last search, so display one cell explaining that
	else if ([searchResultTitles count] == 0)
		return;	
	
	NSString *selectedTitle = [searchResultTitles objectAtIndex:[indexPath row]];
	NSString *selectedPDBCode = [dictionaryToAssociatePDBCodesAndTitles objectForKey:selectedTitle];
	
	SLSMoleculeDownloadViewController *downloadViewController = [[SLSMoleculeDownloadViewController alloc] initWithPDBCode:selectedPDBCode andTitle:selectedTitle];
	downloadViewController.delegate = self;
	
	[self.navigationController pushViewController:downloadViewController animated:YES];
	[downloadViewController release];	
}


/*
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	
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


- (void)viewDidLoad {
	[super viewDidLoad];
}


- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
}

- (void)viewDidDisappear:(BOOL)animated {
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

- (BOOL)performSearchWithKeyword:(NSString *)keyword;
{
	// Clear the old search results table
	[searchResultPDBCodes release];
	searchResultPDBCodes = nil;
	[searchResultTitles release];
	searchResultTitles = nil;

		// TODO: Refresh the table
	
	NSString *webServicesURL = @"http://www.pdb.org/pdb/services/pdbws";
	NSMutableURLRequest *theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:webServicesURL]
											  cachePolicy:NSURLRequestUseProtocolCachePolicy
										  timeoutInterval:60.0];
	theRequest.HTTPMethod = @"POST";
	[theRequest setValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
	[theRequest setValue:@"" forHTTPHeaderField:@"Soapaction"];
	[theRequest setValue:@"www.pdb.org" forHTTPHeaderField:@"Host"];
	NSString *pdbQueryBody = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<SOAP-ENV:Envelope\nxmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"\n	xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\nxmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\"\nSOAP-ENV:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"\nxmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\">	<SOAP-ENV:Body>\n<m:keywordQuery xmlns:m=\"webservices.pdb.org\">\n<in0 xsi:type=\"xsd:string\">%@</in0>\n<in1 xsi:type=\"xsd:boolean\">false</in1>\n<in2 xsi:type=\"xsd:boolean\">false</in2>\n</m:keywordQuery>\n</SOAP-ENV:Body>\n</SOAP-ENV:Envelope>", keyword];
	
	theRequest.HTTPBody = [pdbQueryBody dataUsingEncoding:NSUTF8StringEncoding];

	NSString *bodyString = [[NSString alloc] initWithData:[theRequest HTTPBody] encoding:NSUTF8StringEncoding];
	[bodyString release];
		
	downloadedFileContents = [[NSMutableData data] retain];
	pdbCodeRetrievalConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	if (pdbCodeRetrievalConnection) 
	{
		[self.tableView reloadData];
	} 
	else 
	{
		return NO;
	}
	return YES;
}

- (void)processSearchResults;
{
	[pdbCodeRetrievalConnection release];
	pdbCodeRetrievalConnection = nil;

	[searchResultPDBCodes release];
	searchResultPDBCodes = nil;
	searchResultPDBCodes = [[NSMutableArray alloc] init];

	[searchResultsParser release];
	
	[currentXMLElementString release];
    currentXMLElementString = nil;

	searchResultsParser = [[NSXMLParser alloc] initWithData:downloadedFileContents];
	[downloadedFileContents release];
	downloadedFileContents = nil;
    searchResultsParser.delegate = self;
    [searchResultsParser setShouldResolveExternalEntities:YES];
    [searchResultsParser parse]; 	
}

- (BOOL)finishParsingXML;
{
	// Trim back the results to the max allowed
	if ([searchResultPDBCodes count] > MAX_SEARCH_RESULT_CODES)
		[searchResultPDBCodes removeObjectsInRange:NSMakeRange(50, ([searchResultPDBCodes count] - 50))];
	
	
	// Initiate URL query to get titles
	NSMutableString *urlForPDBTitleRequest = [NSMutableString stringWithString:@"http://www.rcsb.org/pdb/results/titles.jsp?structureIdList="];
	for (NSString *currentPDBCode in searchResultPDBCodes)
	{
		[urlForPDBTitleRequest appendString:@","];
		[urlForPDBTitleRequest appendString:currentPDBCode];
	}
	
	NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:urlForPDBTitleRequest]
											  cachePolicy:NSURLRequestUseProtocolCachePolicy
										  timeoutInterval:60.0];

	downloadedFileContents = [[NSMutableData data] retain];
	titleRetrievalConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	[self.tableView reloadData];
	if (titleRetrievalConnection) 
	{
	} 
	else 
	{
		return NO;
	}
	return YES;
}

- (void)finishLoadingTitles;
{
	NSCharacterSet *semicolonSet = [NSCharacterSet characterSetWithCharactersInString:@";"];

	NSString *titlesForPDBCodes = [[NSString alloc] initWithData:downloadedFileContents encoding:NSASCIIStringEncoding];
	[downloadedFileContents release];
	downloadedFileContents = nil;
	
	searchResultTitles = [[NSMutableArray alloc] init];
	
	NSUInteger length = [titlesForPDBCodes length];
	NSUInteger lineStart = 0, lineEnd = 0, contentsEnd = 0;
	NSRange currentRange;
	
	while (lineEnd < length) 
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

		[titlesForPDBCodes getParagraphStart:&lineStart end:&lineEnd contentsEnd:&contentsEnd forRange:NSMakeRange(lineEnd, 0)];
		currentRange = NSMakeRange(lineStart, contentsEnd - lineStart);
		NSString *currentLine = [titlesForPDBCodes substringWithRange:currentRange];
		
		//NSString *currentPDBCode = [[currentLine substringWithRange:NSMakeRange(0, 4)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString *currentTitle = [[currentLine substringFromIndex:4] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		currentTitle = [currentTitle lowercaseString];
		currentTitle = [currentTitle titlecaseString];
		currentTitle = [currentTitle stringByTrimmingCharactersInSet:semicolonSet];
		
		[searchResultTitles addObject:currentTitle];
		[pool release];
	}		
	[titlesForPDBCodes release];
	titlesForPDBCodes = nil;
	
	[dictionaryToAssociatePDBCodesAndTitles release];
	if ([searchResultTitles count] < 1)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error in search query", @"Localized", nil) message:NSLocalizedStringFromTable(@"The RCSB Protein Data Bank is not responding to requests for molecule titles.  Only the PDB codes of the results will be displayed.", @"Localized", nil)
													   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];
		[alert release];					
		
		
		searchResultTitles = [searchResultPDBCodes copy];
	}
	
	
	if ([searchResultPDBCodes count] < [searchResultTitles count])
		[searchResultTitles removeLastObject];
	else if ([searchResultPDBCodes count] > [searchResultTitles count])
		[searchResultPDBCodes removeLastObject];
	dictionaryToAssociatePDBCodesAndTitles = [[NSMutableDictionary alloc] initWithObjects:searchResultPDBCodes forKeys:searchResultTitles];
	[searchResultPDBCodes release];
	searchResultPDBCodes = nil;
	// Sort title array by the first instance of the keyword in the name
	// Match PDB code to title when tapping for a detail view	
	
	[self.tableView reloadData];
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
	
	[downloadedFileContents release];
	downloadedFileContents = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
{
	// Concatenate the new data with the existing data to build up the downloaded file
	// Update the status of the download
	
	[downloadedFileContents appendData:data];

	if (connection == pdbCodeRetrievalConnection)
	{
		if ([downloadedFileContents length] > MAX_SEARCH_RESULT_BYTES)
		{
			[connection cancel];
			[self processSearchResults];
		}
		
	}

	if (searchCancelled)
	{
		[connection cancel];
		[downloadedFileContents release];
		downloadedFileContents = nil;
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
	if (connection == pdbCodeRetrievalConnection)
	{
		[self processSearchResults];
	}
	else
	{
		[titleRetrievalConnection release];
		titleRetrievalConnection = nil;
		[self finishLoadingTitles];
	}
}

#pragma mark -
#pragma mark NSXMLParser delegate methods

// Append new characters from within the element to an existing, or newly created, string
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string 
{
    if (currentXMLElementString == nil) 
	{
		currentXMLElementString= [[NSMutableString alloc] init];
    }
    [currentXMLElementString appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
{
	if ([elementName isEqualToString:@"keywordQueryReturn"])
	{
		// Last item is nil, check for that
		if (currentXMLElementString != nil)
			[searchResultPDBCodes addObject:currentXMLElementString];
	}
	
	[currentXMLElementString release];
    currentXMLElementString = nil;
}

- (void)parserDidEndDocument:(NSXMLParser *)parser;
{
	[self finishParsingXML];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
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

