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

- (id)initWithPDBCode:(NSString *)pdbCode andTitle:(NSString *)title;
{
	if ((self = [super init])) 
	{
		// Initialization code
		downloadedFileContents = nil;
		downloadCancelled = NO;
		
		codeForCurrentlyDownloadingProtein = [pdbCode copy];
		titleForCurrentlyDownloadingProtein = [title copy];		
	}
	return self;
}


- (void)dealloc;
{
	[self cancelDownload];
	[codeForCurrentlyDownloadingProtein release];
	[titleForCurrentlyDownloadingProtein release];
	[super dealloc];
}

#pragma mark -
#pragma mark Protein downloading

- (IBAction)downloadNewProtein;
{
	// Check if you already have a protein by that name
	// TODO: Put this check in the init method to grey out download button
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];

	if ([[NSFileManager defaultManager] fileExistsAtPath:[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.pdb.gz", codeForCurrentlyDownloadingProtein]]])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"File already exists", @"Localized", nil) message:NSLocalizedStringFromTable(@"The molecule with this PDB code has already been downloaded", @"Localized", nil)
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
		alert.backgroundColor = [UIColor redColor];
		[alert show];
		[alert release];
		return;
	}
	
	if (![self downloadPDBFile])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Connection failed", @"Localized", nil) message:NSLocalizedStringFromTable(@"Could not connect to the Protein Data Bank", @"Localized", nil)
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
		[alert show];
		[alert release];
		return;
	}
}

- (BOOL)downloadPDBFile;
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
//	downloadStatusText.hidden = NO;
//	downloadStatusText.text = NSLocalizedStringFromTable(@"Connecting...", @"Localized", nil);
		
//	NSString *locationOfRemotePDBFile = [NSString stringWithFormat:@"http://www.sunsetlakesoftware.com/sites/default/files/%@.pdb.gz", pdbCode];
	NSString *locationOfRemotePDBFile = [NSString stringWithFormat:@"http://www.rcsb.org/pdb/files/%@.pdb.gz", codeForCurrentlyDownloadingProtein];

	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:locationOfRemotePDBFile]
											  cachePolicy:NSURLRequestUseProtocolCachePolicy
										  timeoutInterval:60.0];
	downloadConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	if (downloadConnection) 
	{
		// Create the NSMutableData that will hold
		// the received data
		// receivedData is declared as a method instance elsewhere
		downloadedFileContents = [[NSMutableData data] retain];
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
	[downloadConnection release];
	downloadConnection = nil;
	

	[downloadedFileContents release];
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
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Connection failed", @"Localized", nil) message:NSLocalizedStringFromTable(@"Could not connect to the Protein Data Bank", @"Localized", nil)
												   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
	[alert show];
	[alert release];
	
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
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Could not find file", @"Localized", nil) message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"No protein with the code %@ exists in the data bank", @"Localized", nil), codeForCurrentlyDownloadingProtein]
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
		[alert show];
		[alert release];		
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
	NSString *filename = [NSString stringWithFormat:@"%@.pdb.gz", codeForCurrentlyDownloadingProtein];
	
	NSError *error = nil;
	if (![downloadedFileContents writeToFile:[documentsDirectory stringByAppendingPathComponent:filename] options:NSAtomicWrite error:&error])
	{
		// TODO: Do some error handling here
		return;
	}
	
	// Notify about the addition of the new molecule
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MoleculeDidFinishDownloading" object:filename];
	
//	if ([SLSMoleculeAppDelegate isRunningOniPad])
//	{
//		[self.navigationController popViewControllerAnimated:YES];
//	}
	
	[self downloadCompleted];	
}

#pragma mark -
#pragma mark Accessors

@end
