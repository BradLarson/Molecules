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
#import "SLSMoleculeiPadRootViewController.h"
#import "SLSMoleculeGLViewController.h"
#import "SLSMoleculeTableViewController.h"
#import "SLSMolecule.h"
#import "NSData+Gzip.h"

#import "VCTitleCase.h"

#define MOLECULES_DATABASE_VERSION 1

@implementation SLSMoleculeAppDelegate

@synthesize window;
@synthesize rootViewController;

#pragma mark -
#pragma mark Initialization / teardown

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions   
{	
	//Initialize the application window
	window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	if (!window) 
	{
		return NO;
	}
	window.backgroundColor = [UIColor blackColor];

	if ([SLSMoleculeAppDelegate isRunningOniPad])
	{
		UISplitViewController *newSplitViewController = [[UISplitViewController alloc] init];
        if ([newSplitViewController respondsToSelector:@selector(setPresentsWithGesture:)])
        {
            [newSplitViewController setPresentsWithGesture:NO];
        }
        
		rootViewController = [[SLSMoleculeiPadRootViewController alloc] init];
		[rootViewController loadView];
		newSplitViewController.viewControllers = [NSArray arrayWithObjects:rootViewController.tableNavigationController, rootViewController, nil];
		newSplitViewController.delegate = (SLSMoleculeiPadRootViewController *)rootViewController;
		splitViewController = newSplitViewController;
		[window addSubview:splitViewController.view];
	}
	else
	{
		rootViewController = [[SLSMoleculeRootViewController alloc] init];
		[window addSubview:rootViewController.view];
	}
	
	
    [window makeKeyAndVisible];
	[window layoutSubviews];	
	
	// Start the initialization of the database, if necessary
	isHandlingCustomURLMoleculeDownload = NO;
	downloadedFileContents = nil;
	initialDatabaseLoadLock = [[NSLock alloc] init];

	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

	NSURL *url = (NSURL *)[launchOptions valueForKey:UIApplicationLaunchOptionsURLKey];
	
	if (url != nil)
	{
		isHandlingCustomURLMoleculeDownload = YES;		
	}
	
	[self performSelectorInBackground:@selector(loadInitialMoleculesFromDisk) withObject:nil];	
	
	return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	
	if (url != nil)
	{
		isHandlingCustomURLMoleculeDownload = YES;		
	}
	
	// Deal with case where you are in the table view
	if (![SLSMoleculeAppDelegate isRunningOniPad])
	{
		if ([rootViewController.glViewController.view superview] == nil)
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleView" object:nil];
		}
	}
	
	// Handle the Molecules custom URL scheme
	[self handleCustomURLScheme:url];
	
	return YES;
}


#pragma mark -
#pragma mark Device-specific interface control

/*+ (BOOL)isRunningOniPad;
{
	return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
}*/

+ (BOOL)isRunningOniPad;
{
	static BOOL hasCheckediPadStatus = NO;
	static BOOL isRunningOniPad = NO;
	
	if (!hasCheckediPadStatus)
	{
		if ([[UIDevice currentDevice] respondsToSelector:@selector(userInterfaceIdiom)])
		{
			if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
			{
				isRunningOniPad = YES;
				hasCheckediPadStatus = YES;
				return isRunningOniPad;
			}
		}

		hasCheckediPadStatus = YES;
	}
	
	return isRunningOniPad;
}

#pragma mark -
#pragma mark Database access

- (NSString *)cachesDirectory;
{	
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:basePath] == NO)
	{
		NSError *error = nil;
		[fileManager createDirectoryAtPath:basePath withIntermediateDirectories:NO attributes:nil error:&error];
	}
	
    return basePath;
}

- (NSString *)applicationSupportDirectory;
{	
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:basePath] == NO)
	{
		NSError *error = nil;
		[fileManager createDirectoryAtPath:basePath withIntermediateDirectories:NO attributes:nil error:&error];
	}
	
    return basePath;
}

- (BOOL)createEditableCopyOfDatabaseIfNeeded; 
{
    // First, see if the database exists in the /Documents directory.  If so, move it to Application Support.
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:@"molecules.sql"];
    if ([fileManager fileExistsAtPath:writableDBPath])
	{
		[fileManager moveItemAtPath:writableDBPath toPath:[[self cachesDirectory] stringByAppendingPathComponent:@"molecules.sql"] error:&error];
	}
	
    // Move the older database to the proper location for iCloud
    if ([fileManager fileExistsAtPath:[[self applicationSupportDirectory] stringByAppendingPathComponent:@"molecules.sql"]])
	{
		[fileManager moveItemAtPath:[[self applicationSupportDirectory] stringByAppendingPathComponent:@"molecules.sql"] toPath:[[self cachesDirectory] stringByAppendingPathComponent:@"molecules.sql"] error:&error];
	}
    
	writableDBPath = [[self cachesDirectory] stringByAppendingPathComponent:@"molecules.sql"];
	
    if ([fileManager fileExistsAtPath:writableDBPath])
		return NO;
	
    // The database does not exist, so copy a blank starter database to the Documents directory
    NSString *defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"molecules.sql"];
    BOOL success = [fileManager copyItemAtPath:defaultDBPath toPath:writableDBPath error:&error];
    if (!success) {
		NSAssert1(0,NSLocalizedStringFromTable(@"Failed to create writable database file with message '%@'.", @"Localized", nil), [error localizedDescription]);
    }
	return YES;
}

- (void)connectToDatabase;
{
	molecules = [[NSMutableArray alloc] init];
	
	// The database is stored in the application bundle. 
    NSString *path = [[self cachesDirectory] stringByAppendingPathComponent:@"molecules.sql"];
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
		//NSAssert1(0,NSLocalizedStringFromTable(@"Error: failed to close database with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
    }
	
	database = nil;
}

- (void)loadInitialMoleculesFromDisk;
{
	[initialDatabaseLoadLock lock];

	@autoreleasepool {
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
			while ((pname = [direnum nextObject]))
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
			[self performSelectorOnMainThread:@selector(hideStatusIndicator) withObject:nil waitUntilDone:YES];
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

		if ([SLSMoleculeAppDelegate isRunningOniPad])
		{
			[[rootViewController.tableViewController tableView] performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
		}
		
		if (!isHandlingCustomURLMoleculeDownload)
			[rootViewController loadInitialMolecule];
	}
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
	while ((pname = [direnum nextObject]))
	{
		NSString *lastPathComponent = [pname lastPathComponent];
		if (![lastPathComponent isEqualToString:pname])
		{
			NSError *error = nil;
			// The file has been passed in using a subdirectory, so move it into the flattened /Documents directory
			[[NSFileManager defaultManager]	moveItemAtPath:[documentsDirectory stringByAppendingPathComponent:pname] toPath:[documentsDirectory stringByAppendingPathComponent:lastPathComponent] error:&error];
			[[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:[pname stringByDeletingLastPathComponent]] error:&error];
			pname = lastPathComponent;
		}
		
		if ( ([moleculeFilenameLookupTable valueForKey:pname] == nil) && ([[[pname pathExtension] lowercaseString] isEqualToString:@"gz"] || [[[pname pathExtension] lowercaseString] isEqualToString:@"pdb"]) )
		{
			// Parse the PDB file into the database
			SLSMolecule *newMolecule = [[SLSMolecule alloc] initWithFilename:pname database:database title:nil];
			if (newMolecule != nil)
			{
				[molecules addObject:newMolecule];
				if (rootViewController.tableViewController != nil)
				{
					[rootViewController.tableViewController.tableView reloadData];				
				}					
			}
		}
	}
	
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

- (void)applicationWillTerminate:(UIApplication *)application 
{
	if (database != nil)
	{
		[rootViewController cancelMoleculeLoading];
		[self disconnectFromDatabase];
	}
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
/*	if (database == nil)
	{
		[self connectToDatabase];
	}*/
	
	[self loadMissingMoleculesIntoDatabase];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	[rootViewController cancelMoleculeLoading];
//	[self disconnectFromDatabase];
}


#pragma mark -
#pragma mark Custom molecule download methods

- (BOOL)handleCustomURLScheme:(NSURL *)url;
{
	if (url != nil)
	{
		isHandlingCustomURLMoleculeDownload = YES;
		[NSThread sleepForTimeInterval:0.5]; // Wait for database to load
		
		NSString *pathComponentForCustomURL = [[url host] stringByAppendingString:[url path]];
		NSString *locationOfRemotePDBFile = [NSString stringWithFormat:@"http://%@", pathComponentForCustomURL];
		nameOfDownloadedMolecule = [pathComponentForCustomURL lastPathComponent];
		
		// Check to make sure that the file has not already been downloaded, if so, just switch to it
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = [paths objectAtIndex:0];	
		
		[initialDatabaseLoadLock lock];

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
			
			if (rootViewController.tableViewController == nil)
			{
				[rootViewController selectedMoleculeDidChange:indexForMoleculeMatchingThisName];
			}
			else
			{
				if ([SLSMoleculeAppDelegate isRunningOniPad])
				{
					[rootViewController.tableViewController tableView:rootViewController.tableViewController.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:indexForMoleculeMatchingThisName inSection:0]];
				}
				else
				{
					[rootViewController.tableViewController tableView:rootViewController.tableViewController.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:(indexForMoleculeMatchingThisName + 1) inSection:0]];
				}					
			}
			[rootViewController loadInitialMolecule];
			
			nameOfDownloadedMolecule = nil;
			[initialDatabaseLoadLock unlock];
			return YES;
		}
		[initialDatabaseLoadLock unlock];

		
		[rootViewController cancelMoleculeLoading];
		
		[NSThread sleepForTimeInterval:0.1]; // Wait for cancel action to take place
		
		// Determine if this is a file being passed in, or something to download
		if ([url isFileURL])
		{

			nameOfDownloadedMolecule = nil;
		}
		else
		{
			downloadCancelled = NO;
			
			// Start download of new molecule
			[self showDownloadIndicator];
			
			
			[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
			NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:locationOfRemotePDBFile]
													  cachePolicy:NSURLRequestUseProtocolCachePolicy
												  timeoutInterval:60.0f];
			downloadConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
			if (downloadConnection) 
			{
				downloadedFileContents = [NSMutableData data];
			} 
			else 
			{
				// inform the user that the download could not be made
				return NO;
			}
		}
	}	
	return YES;
}

- (void)downloadCompleted;
{
	downloadConnection = nil;
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

	downloadedFileContents = nil;
	[self hideStatusIndicator];
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
		
		SLSMolecule *newMolecule = [[SLSMolecule alloc] initWithFilename:filename database:database title:nil];
		if (newMolecule == nil)
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error in downloaded file", @"Localized", nil) message:NSLocalizedStringFromTable(@"The molecule file is either corrupted or not of a supported format", @"Localized", nil)
														   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles:nil, nil];
			[alert show];
			
			// Delete the corrupted or sunsupported file
			NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
			NSString *documentsDirectory = [paths objectAtIndex:0];
			
			NSError *error = nil;
			if (![[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:filename] error:&error])
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Could not delete file", @"Localized", nil) message:[error localizedDescription]
															   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles:nil, nil];
				[alert show];
				return;
			}
			
		}
		else
		{			
			[molecules addObject:newMolecule];
			
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
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil, nil];
		[alert show];
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
