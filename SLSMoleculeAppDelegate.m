//
//  SLSMoleculesAppDelegate.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 5/18/2008.
//
//  This is the base application delegate, used for handling launch, termination, and memory-related delegate methods

#import "SLSMoleculeAppDelegate.h"
#import "SLSMoleculeRootViewController.h"
#import "SLSMolecule.h"
#import "NSData+Gzip.h"

#import "VCTitleCase.h"

#define MOLECULES_DATABASE_VERSION 1

@implementation SLSMoleculeAppDelegate

@synthesize window;
@synthesize rootViewController;

#pragma mark -
#pragma mark Initialization / teardown

- (void)applicationDidFinishLaunching:(UIApplication *)application 
{	
	isHandlingCustomURLMoleculeDownload = NO;
	downloadedFileContents = nil;
	initialDatabaseLoadLock = [[NSLock alloc] init];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];


	// This lets the little network activity indicator in the top status bar show when something is being sent or received
	
	[self performSelectorInBackground:@selector(loadInitialMoleculesFromDisk) withObject:nil];
	
	[window addSubview:[rootViewController view]];
	[window makeKeyAndVisible];
	
//	UIApplication* app = [UIApplication sharedApplication];
//	[self application:app handleOpenURL:[NSURL URLWithString:@"molecules://www.sunsetlakesoftware.com/sites/default/files/xenonPump.pdb"]];
}

- (void)applicationWillTerminate:(UIApplication *)application 
{
	[self disconnectFromDatabase];
}

- (void)dealloc 
{
	[initialDatabaseLoadLock release];
	[rootViewController release];
	[molecules release];
	[window release];
	[super dealloc];
}

#pragma mark -
#pragma mark Database access

- (BOOL)createEditableCopyOfDatabaseIfNeeded; 
{
    // See if the database already exists
    BOOL success;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:@"molecules.sql"];
    success = [fileManager fileExistsAtPath:writableDBPath];
    if (success) return NO;
	
    // The database does not exist, so copy a blank starter database to the Documents directory
    NSString *defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"molecules.sql"];
    success = [fileManager copyItemAtPath:defaultDBPath toPath:writableDBPath error:&error];
    if (!success) {
		NSAssert1(0,NSLocalizedStringFromTable(@"Failed to create writable database file with message '%@'.", @"Localized", nil), [error localizedDescription]);
    }
	return YES;
}

- (void)connectToDatabase;
{
	molecules = [[NSMutableArray alloc] init];
	
	// The database is stored in the application bundle. 
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"molecules.sql"];
    // Open the database. The database was prepared outside the application.
    if (sqlite3_open([path UTF8String], &database) == SQLITE_OK) 
	{
    } 
	else 
	{
        // Even though the open failed, call close to properly clean up resources.
        sqlite3_close(database);
		NSAssert1(0,NSLocalizedStringFromTable(@"Failed to open database with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
        // Additional error handling, as appropriate...
    }
	
}

- (void)disconnectFromDatabase;
{
// TODO: Maybe write out all database entries to disk
	//	[books makeObjectsPerformSelector:@selector(dehydrate)];
	[SLSMolecule finalizeStatements];
    // Close the database.
    if (sqlite3_close(database) != SQLITE_OK) 
	{
		NSAssert1(0,NSLocalizedStringFromTable(@"Error: failed to close database with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
    }
}

- (void)loadInitialMoleculesFromDisk;
{
	[initialDatabaseLoadLock lock];

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	rootViewController.molecules = nil;

	if ([self createEditableCopyOfDatabaseIfNeeded])
	{
		// The database needed to be recreated, so scan and copy over the default files
		[self performSelectorOnMainThread:@selector(showStatusIndicator) withObject:nil waitUntilDone:NO];
		
		[self connectToDatabase];
		// Before anything else, move included PDB files to /Documents if the program hasn't been run before
		// User might have intentionally deleted files, so don't recopy the files in that case
		NSError *error = nil;
		// Grab the /Documents directory path
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = [paths objectAtIndex:0];
		
		NSFileManager *fileManager = [NSFileManager defaultManager];
		// Iterate through all files sitting in the application's Resources directory
		// TODO: Can you fast enumerate this?
		NSDirectoryEnumerator *direnum = [fileManager enumeratorAtPath:[[NSBundle mainBundle] resourcePath]];
		NSString *pname;
		while (pname = [direnum nextObject])
		{
			if ([[pname pathExtension] isEqualToString:@"gz"])
			{
				NSString *preloadedPDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:pname];
				NSString *installedPDBPath = [documentsDirectory stringByAppendingPathComponent:pname];
				if (![fileManager fileExistsAtPath:installedPDBPath])
				{
					// Move included PDB files to /Documents
					[[NSFileManager defaultManager]	copyItemAtPath:preloadedPDBPath toPath:installedPDBPath error:&error];
					if (error != nil)
					{
//						NSLog(@"Failed to copy over PDB files with error: '%@'.", [error localizedDescription]);
						// TODO: Report the file copying problem to the user or do something about it
					}
				}
				
			}
		}
		
		[self loadMissingMoleculesIntoDatabase];
		
		[[NSUserDefaults standardUserDefaults] synchronize];		
		[self performSelectorOnMainThread:@selector(hideStatusIndicator) withObject:nil waitUntilDone:NO];
	}
	else
	{
		// The MySQL database has been created, so load molecules from the database
		[self connectToDatabase];
		// TODO: Check to make sure that the proper version of the database is installed
		[self loadAllMoleculesFromDatabase];
		[self loadMissingMoleculesIntoDatabase];		
	}
	
	rootViewController.database = database;
	rootViewController.molecules = molecules;
	[initialDatabaseLoadLock unlock];

	if (!isHandlingCustomURLMoleculeDownload)
		[rootViewController loadInitialMolecule];
	[pool release];
}

- (void)loadAllMoleculesFromDatabase;
{
	const char *sql = "SELECT * FROM molecules";
	sqlite3_stmt *moleculeLoadingStatement;

	if (sqlite3_prepare_v2(database, sql, -1, &moleculeLoadingStatement, NULL) == SQLITE_OK) 
	{
		while (sqlite3_step(moleculeLoadingStatement) == SQLITE_ROW) 
		{
			SLSMolecule *newMolecule = [[SLSMolecule alloc] initWithSQLStatement:moleculeLoadingStatement database:database];
			if (newMolecule != nil)
				[molecules addObject:newMolecule];
				
			[newMolecule release];
		}
	}
	// "Finalize" the statement - releases the resources associated with the statement.
	sqlite3_finalize(moleculeLoadingStatement);	
}

- (void)loadMissingMoleculesIntoDatabase;
{
	// First, load all molecule names from the database
	NSMutableDictionary *moleculeFilenameLookupTable = [[NSMutableDictionary alloc] init];
	
	const char *sql = "SELECT * FROM molecules";
	sqlite3_stmt *moleculeLoadingStatement;
	
	if (sqlite3_prepare_v2(database, sql, -1, &moleculeLoadingStatement, NULL) == SQLITE_OK) 
	{
		while (sqlite3_step(moleculeLoadingStatement) == SQLITE_ROW) 
		{
			char *stringResult = (char *)sqlite3_column_text(moleculeLoadingStatement, 1);
			NSString *sqlString =  (stringResult) ? [NSString stringWithUTF8String:stringResult]  : @"";
			NSString *filename = [sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"];
			[moleculeFilenameLookupTable setValue:[NSNumber numberWithBool:YES] forKey:filename];
		}
	}
	sqlite3_finalize(moleculeLoadingStatement);	
	
	// Now, check all the files on disk to see if any are missing from the database
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	
	NSDirectoryEnumerator *direnum = [[NSFileManager defaultManager]
									  enumeratorAtPath:documentsDirectory];
	NSString *pname;
	while (pname = [direnum nextObject])
	{
		if ( ([moleculeFilenameLookupTable valueForKey:pname] == nil) && ([[pname pathExtension] isEqualToString:@"gz"]) )
		{
			// Parse the PDB file into the database
			SLSMolecule *newMolecule = [[SLSMolecule alloc] initWithFilename:pname database:database];
			if (newMolecule != nil)
				[molecules addObject:newMolecule];
			[newMolecule release];			
		}
	}
	
	[moleculeFilenameLookupTable release];
}

#pragma mark -
#pragma mark Status update methods

- (void)showStatusIndicator;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"FileLoadingStarted" object:NSLocalizedStringFromTable(@"Initializing database...", @"Localized", nil)];
}

- (void)showDownloadIndicator;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"FileLoadingStarted" object:NSLocalizedStringFromTable(@"Downloading molecule...", @"Localized", nil)];
}

- (void)updateStatusIndicator;
{
	
}

- (void)hideStatusIndicator;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"FileLoadingEnded" object:nil];
}

#pragma mark -
#pragma mark Flow control

- (void)applicationWillResignActive:(UIApplication *)application 
{
	[[NSUserDefaults standardUserDefaults] synchronize];		
}

- (void)applicationDidBecomeActive:(UIApplication *)application 
{
}

#pragma mark - 
#pragma mark Custom URL handler

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	NSString *pathComponentForCustomURL = [[url host] stringByAppendingString:[url path]];
	NSString *locationOfRemotePDBFile = [NSString stringWithFormat:@"http://%@", pathComponentForCustomURL];
	nameOfDownloadedMolecule = [[pathComponentForCustomURL lastPathComponent] retain];

	// Check to make sure that the file has not already been downloaded, if so, just switch to it
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];	
	if ([[NSFileManager defaultManager] fileExistsAtPath:[documentsDirectory stringByAppendingPathComponent:nameOfDownloadedMolecule]])
	{
		NSInteger indexForMoleculeMatchingThisName = 0, currentIndex = 0;
		for (SLSMolecule *currentMolecule in molecules)
		{
			if ([[currentMolecule filename] isEqualToString:nameOfDownloadedMolecule])
			{
				indexForMoleculeMatchingThisName = currentIndex;
				break;
			}
			currentIndex++;
		}
		
		[rootViewController selectedMoleculeDidChange:indexForMoleculeMatchingThisName];
		[rootViewController loadInitialMolecule];

		return YES;
	}
		
	isHandlingCustomURLMoleculeDownload = YES;
	[NSThread sleepForTimeInterval:0.1]; // Wait for cancel action to take place

	[rootViewController cancelMoleculeLoading];

	[NSThread sleepForTimeInterval:0.1]; // Wait for cancel action to take place

	downloadCancelled = NO;

	// Start download of new molecule
	[self showDownloadIndicator];
	

	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:locationOfRemotePDBFile]
											  cachePolicy:NSURLRequestUseProtocolCachePolicy
										  timeoutInterval:60.0f];
	NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	if (theConnection) 
	{
		downloadedFileContents = [[NSMutableData data] retain];
	} 
	else 
	{
		// inform the user that the download could not be made
		return NO;
	}
	return YES;
}

#pragma mark -
#pragma mark Custom molecule download methods

- (void)downloadCompleted;
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

	[downloadedFileContents release];
	downloadedFileContents = nil;
	[self hideStatusIndicator];
	[nameOfDownloadedMolecule release];
	nameOfDownloadedMolecule = nil;
}

- (void)saveMoleculeWithData:(NSData *)moleculeData toFilename:(NSString *)filename;
{
	[initialDatabaseLoadLock lock];

	if (moleculeData != nil)
	{
		// Add the new protein to the list by gunzipping the data and pulling out the title
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = [paths objectAtIndex:0];
		
		NSError *error = nil;
		BOOL writeStatus;
		if (isGzipCompressionUsedOnDownload)
		{
			writeStatus = [moleculeData writeToFile:[documentsDirectory stringByAppendingPathComponent:filename] options:NSAtomicWrite error:&error];
//			writeStatus = [[moleculeData gzipDeflate] writeToFile:[documentsDirectory stringByAppendingPathComponent:filename] options:NSAtomicWrite error:&error];			
//			NSLog(@"Decompressing");
		}
		else
			writeStatus = [moleculeData writeToFile:[documentsDirectory stringByAppendingPathComponent:filename] options:NSAtomicWrite error:&error];

		if (!writeStatus)
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
			
			[rootViewController updateTableListOfMolecules];
			[rootViewController selectedMoleculeDidChange:([molecules count] - 1)];
			[rootViewController loadInitialMolecule];

		}			
	}	
	[initialDatabaseLoadLock unlock];

}

#pragma mark -
#pragma mark URL connection delegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Connection failed", @"Localized", nil) message:NSLocalizedStringFromTable(@"Could not connect to the Protein Data Bank", @"Localized", nil)
												   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
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
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
{
//	downloadFileSize = [response expectedContentLength];
	NSString * contentEncoding = [[(NSHTTPURLResponse *)response allHeaderFields] valueForKey:@"Content-Encoding"];
//	NSDictionary *allHeaders = [(NSHTTPURLResponse *)response allHeaderFields];
	isGzipCompressionUsedOnDownload = [[contentEncoding lowercaseString] isEqualToString:@"gzip"];

//	for (id key in allHeaders) 
//	{
//		NSLog(@"key: %@, value: %@", key, [allHeaders objectForKey:key]);
//	}
//	
//	if (isGzipCompressionUsedOnDownload)
//		NSLog(@"gzipping");
	
	// Stop the spinning wheel and start the status bar for download
	if ([response textEncodingName] != nil)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Could not find file", @"Localized", nil) message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"No such file exists on the server: %@", @"Localized", nil), nameOfDownloadedMolecule]
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
		[alert show];
		[alert release];		
		[connection cancel];
		[self downloadCompleted];
		return;
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
{	
	
//	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Download completed" message:@"Download completed"
//												   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
//	[alert show];
//	[alert release];
	
	// Close off the file and write it to disk
	[self saveMoleculeWithData:downloadedFileContents toFilename:nameOfDownloadedMolecule];
	
	[self downloadCompleted];	
}

@end
