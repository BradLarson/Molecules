//
//  SLSMoleculeDownloadViewController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 7/2/2008.
//
//  This controller manages the pop-up modal view for downloading new molecules from the Protein Data Bank

#import "SLSMoleculeDownloadController.h"
#import "SLSMoleculeAppDelegate.h"

@implementation SLSMoleculeDownloadController

- (id)initWithID:(NSString *)pdbCode title:(NSString *)title searchType:(SLSSearchType)newSearchType;
{
	if ((self = [super init])) 
	{
		// Initialization code
		downloadedFileContents = nil;
		downloadCancelled = NO;
        
        searchType = newSearchType;
		
		codeForCurrentlyDownloadingMolecule = [pdbCode copy];
		titleForCurrentlyDownloadingMolecule = [title copy];		
	}
	return self;
}


- (void)dealloc;
{
	[self cancelDownload];
}

#pragma mark -
#pragma mark Protein downloading

- (void)downloadNewMolecule;
{
	// Check if you already have a protein by that name
	// TODO: Put this check in the init method to grey out download button
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];

    NSString *fileExtension = nil;
    if (searchType == PROTEINDATABANKSEARCH)
    {
        fileExtension = @"pdb.gz";
    }
    else
    {
        fileExtension = @"sdf";        
    }
    
	if ([[NSFileManager defaultManager] fileExistsAtPath:[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", codeForCurrentlyDownloadingMolecule, fileExtension]]])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"File already exists", @"Localized", nil) message:NSLocalizedStringFromTable(@"This molecule has already been downloaded", @"Localized", nil)
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
		[alert show];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MoleculeDidFinishDownloading" object:nil];
		return;
	}
	
	if (![self downloadMolecule])
	{
        NSString *errorMessage = nil;
        
        if (searchType == PROTEINDATABANKSEARCH)
        {
            errorMessage = NSLocalizedStringFromTable(@"Could not connect to the Protein Data Bank", @"Localized", nil);
        }
        else
        {
            errorMessage = NSLocalizedStringFromTable(@"Could not connect to PubChem", @"Localized", nil);
        }
        
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Connection failed", @"Localized", nil) message:errorMessage
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
		[alert show];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MoleculeDidFinishDownloading" object:nil];
		return;
	}
}

- (BOOL)downloadMolecule;
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
//	downloadStatusText.hidden = NO;
//	downloadStatusText.text = NSLocalizedStringFromTable(@"Connecting...", @"Localized", nil);
		
//	NSString *locationOfRemotePDBFile = [NSString stringWithFormat:@"http://www.sunsetlakesoftware.com/sites/default/files/%@.pdb.gz", pdbCode];
	NSString *locationOfRemoteFile  = nil;
    if (searchType == PROTEINDATABANKSEARCH)
    {
        locationOfRemoteFile = [NSString stringWithFormat:@"http://www.rcsb.org/pdb/files/%@.pdb.gz", codeForCurrentlyDownloadingMolecule];
    }
    else
    {
        locationOfRemoteFile = [NSString stringWithFormat:@"http://pubchem.ncbi.nlm.nih.gov/summary/summary.cgi?cid=%@&disopt=3DSaveSDF", codeForCurrentlyDownloadingMolecule];
    }

	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:locationOfRemoteFile]
											  cachePolicy:NSURLRequestUseProtocolCachePolicy
										  timeoutInterval:60.0];
	downloadConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	if (downloadConnection) 
	{
		// Create the NSMutableData that will hold
		// the received data
		// receivedData is declared as a method instance elsewhere
		downloadedFileContents = [NSMutableData data];
	} 
	else 
	{
		// inform the user that the download could not be made
		return NO;
	}
	return YES;
}

- (void)downloadCompleted;
{
	downloadConnection = nil;
	

	downloadedFileContents = nil;
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (void)cancelDownload;
{
	downloadCancelled = YES;
}

#pragma mark -
#pragma mark URL connection delegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
{
    NSString *errorMessage = nil;
    
    if (searchType == PROTEINDATABANKSEARCH)
    {
        errorMessage = NSLocalizedStringFromTable(@"Could not connect to the Protein Data Bank", @"Localized", nil);
    }
    else
    {
        errorMessage = NSLocalizedStringFromTable(@"Could not connect to PubChem", @"Localized", nil);
    }

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Connection failed", @"Localized", nil) message:errorMessage
												   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
	[alert show];
	
	[self downloadCompleted];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
{
	// Concatenate the new data with the existing data to build up the downloaded file
	// Update the status of the download

	if (downloadCancelled)
	{
		[connection cancel];
		[self downloadCompleted];
		downloadCancelled = NO;
		return;
	}
	[downloadedFileContents appendData:data];
//	downloadStatusBar.progress = (float)[downloadedFileContents length] / (float)downloadFileSize;
//	downloadStatusText.text = NSLocalizedStringFromTable(@"Downloading", @"Localized", nil);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
{
	downloadFileSize = [response expectedContentLength];
	
	// Stop the spinning wheel and start the status bar for download
	if ([response textEncodingName] != nil)
	{
        NSString *errorMessage = nil;
        
        if (searchType == PROTEINDATABANKSEARCH)
        {
            errorMessage = [NSString stringWithFormat:NSLocalizedStringFromTable(@"No protein with the code %@ exists in the data bank", @"Localized", nil), codeForCurrentlyDownloadingMolecule];
        }
        else
        {
            errorMessage = [NSString stringWithFormat:NSLocalizedStringFromTable(@"No structure file for the compound with the code %@ exists at PubChem", @"Localized", nil), codeForCurrentlyDownloadingMolecule];
        }

		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Could not find file", @"Localized", nil) message:errorMessage
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
		[alert show];
		[connection cancel];
		[self downloadCompleted];
		return;
	}
	
	if (downloadFileSize > 0)
	{
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	}
//	downloadStatusText.text = NSLocalizedStringFromTable(@"Connected", @"Localized", nil);

	// TODO: Deal with a 404 error by checking filetype header
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
{
//	downloadStatusText.text = NSLocalizedStringFromTable(@"Processing...", @"Localized", nil);

	// Close off the file and write it to disk	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *fileExtension = nil;
    if (searchType == PROTEINDATABANKSEARCH)
    {
        fileExtension = @"pdb.gz";
    }
    else
    {
        fileExtension = @"sdf";        
    }

	NSString *filename = [NSString stringWithFormat:@"%@.%@", codeForCurrentlyDownloadingMolecule, fileExtension];
	
	NSError *error = nil;
	if (![downloadedFileContents writeToFile:[documentsDirectory stringByAppendingPathComponent:filename] options:NSAtomicWrite error:&error])
	{
		// TODO: Do some error handling here
		return;
	}
	
	// Notify about the addition of the new molecule
    if (searchType == PROTEINDATABANKSEARCH)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MoleculeDidFinishDownloading" object:filename];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MoleculeDidFinishDownloading" object:filename userInfo:[NSDictionary dictionaryWithObject:titleForCurrentlyDownloadingMolecule forKey:@"title"]];        
    }
	
//	if ([SLSMoleculeAppDelegate isRunningOniPad])
//	{
//		[self.navigationController popViewControllerAnimated:YES];
//	}
	
	[self downloadCompleted];	
}

#pragma mark -
#pragma mark Accessors

@end
