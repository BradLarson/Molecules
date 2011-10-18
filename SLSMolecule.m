//
//  SLSMolecule.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/26/2008.
//
//  This is the model class for the molecule object.  It parses a PDB file, generates a vertex buffer object, and renders that object to the screen

#import "SLSMolecule.h"
// Filetypes
#import "SLSMolecule+PDB.h"
#import "SLSMolecule+SDF.h"

#import "SLSOpenGLESRenderer.h"
#import "SLSOpenGLES20Renderer.h"

NSString *const kSLSMoleculeRenderingStartedNotification = @"MoleculeRenderingStarted";
NSString *const kSLSMoleculeRenderingUpdateNotification = @"MoleculeRenderingUpdate";
NSString *const kSLSMoleculeRenderingEndedNotification = @"MoleculeRenderingEnded";

#define BOND_LENGTH_LIMIT 3.0f

static sqlite3_stmt *insertMoleculeSQLStatement = nil;
static sqlite3_stmt *insertMetadataSQLStatement = nil;
static sqlite3_stmt *insertAtomSQLStatement = nil;
static sqlite3_stmt *insertBondSQLStatement = nil;

static sqlite3_stmt *updateMoleculeSQLStatement = nil;

static sqlite3_stmt *retrieveMoleculeSQLStatement = nil;
static sqlite3_stmt *retrieveMetadataSQLStatement = nil;
static sqlite3_stmt *retrieveAtomSQLStatement = nil;
static sqlite3_stmt *retrieveBondSQLStatement = nil;

static sqlite3_stmt *deleteMoleculeSQLStatement = nil;
static sqlite3_stmt *deleteMetadataSQLStatement = nil;
static sqlite3_stmt *deleteAtomSQLStatement = nil;
static sqlite3_stmt *deleteBondSQLStatement = nil;


@implementation SLSMolecule

#pragma mark -
#pragma mark Initialization and deallocation

- (id)init;
{
    if (!(self = [super init]))
    {
        return nil;
    }
        
	numberOfStructures = 1;
	numberOfStructureBeingDisplayed = 1;
	
	filename = nil;
	filenameWithoutExtension = nil;
	title = nil;
	keywords = nil;
	sequence = nil;
	compound = nil;
	source = nil;
	journalTitle = nil;
	journalAuthor = nil;
	journalReference = nil;
	author = nil;
	
	isBeingDisplayed = NO;
	isRenderingCancelled = NO;
	
	previousTerminalAtomValue = nil;
	reverseChainDirection = NO;
	currentVisualizationType = BALLANDSTICK;
	
	isPopulatedFromDatabase = NO;
	databaseKey = 0;
	isDoneRendering = NO;

	stillCountingAtomsInFirstStructure = YES;
	return self;
}

- (id)initWithFilename:(NSString *)newFilename database:(sqlite3 *)newDatabase title:(NSString *)newTitle;
{
    if (!(self = [self init]))
    {
        return nil;
    }

	database = newDatabase;
	filename = [newFilename copy];
    title = [newTitle copy];
	
	NSRange rangeUntilFirstPeriod = [filename rangeOfString:@"."];
	if (rangeUntilFirstPeriod.location == NSNotFound)
    {
		filenameWithoutExtension = filename;
    }
	else
    {
		filenameWithoutExtension = [filename substringToIndex:rangeUntilFirstPeriod.location];	
    }
	
	if (insertMoleculeSQLStatement == nil) 
	{
        static char *sql = "INSERT INTO molecules (filename) VALUES(?)";
        if (sqlite3_prepare_v2(database, sql, -1, &insertMoleculeSQLStatement, NULL) != SQLITE_OK) 
		{
            NSAssert1(0,NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
        }
    }
	// Bind the query variables.
	sqlite3_bind_text(insertMoleculeSQLStatement, 1, [filename UTF8String], -1, SQLITE_TRANSIENT);
    int success = sqlite3_step(insertMoleculeSQLStatement);
    // Because we want to reuse the statement, we "reset" it instead of "finalizing" it.
    sqlite3_reset(insertMoleculeSQLStatement);
    if (success != SQLITE_ERROR) 
	{
        // SQLite provides a method which retrieves the value of the most recently auto-generated primary key sequence
        // in the database. To access this functionality, the table should have a column declared of type 
        // "INTEGER PRIMARY KEY"
        databaseKey = sqlite3_last_insert_rowid(database);
    }
	
	NSError *error = nil;
    
    if ([[[filename pathExtension] lowercaseString] isEqualToString:@"sdf"])
    {
        if (![self readFromSDFFileToDatabase:&error])
        {
            return nil;
        }
    }
    else
    {
        if (![self readFromPDBFileToDatabase:&error])
        {
            return nil;
        }
    }
	
	return self;
}

- (id)initWithSQLStatement:(sqlite3_stmt *)moleculeRetrievalStatement database:(sqlite3 *)newDatabase;
{
    if (!(self = [self init]))
    {
        return nil;
    }

	database = newDatabase;
	
	// Retrieve molecule information from the line of the SELECT statement
	//(id,filename,title,compound,format,atom_count,structure_count, centerofmass_x,centerofmass_y,centerofmass_z,minimumposition_x,minimumposition_y,minimumposition_z,maximumposition_x,maximumposition_y,maximumposition_z)
	databaseKey = sqlite3_column_int(moleculeRetrievalStatement, 0);
	char *stringResult = (char *)sqlite3_column_text(moleculeRetrievalStatement, 1);
	NSString *sqlString =  (stringResult) ? [NSString stringWithUTF8String:stringResult]  : @"";
	filename = [sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"];
	
	NSRange rangeUntilFirstPeriod = [filename rangeOfString:@"."];
	if (rangeUntilFirstPeriod.location == NSNotFound)
		filenameWithoutExtension = filename;
	else
		filenameWithoutExtension = [filename substringToIndex:rangeUntilFirstPeriod.location];
	
	stringResult = (char *)sqlite3_column_text(moleculeRetrievalStatement, 2);
	sqlString =  (stringResult) ? [NSString stringWithUTF8String:stringResult]  : @"";
	title = [sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"];

	stringResult = (char *)sqlite3_column_text(moleculeRetrievalStatement, 3);
	sqlString =  (stringResult) ? [NSString stringWithUTF8String:stringResult]  : @"";
	compound = [sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"];
	
	// Ignore the format for now
	//	stringResult = (char *)sqlite3_column_text(moleculeRetrievalStatement, 4);
	//	format = (stringResult) ? [[NSString alloc] initWithUTF8String:stringResult]  : [[NSString alloc] initWithString:@""];
	numberOfAtoms = sqlite3_column_int(moleculeRetrievalStatement, 5);
	numberOfBonds = sqlite3_column_int(moleculeRetrievalStatement, 6);
	numberOfStructures = sqlite3_column_int(moleculeRetrievalStatement, 7);
	centerOfMassInX = sqlite3_column_double(moleculeRetrievalStatement, 8);
	centerOfMassInY = sqlite3_column_double(moleculeRetrievalStatement, 9);
	centerOfMassInZ = sqlite3_column_double(moleculeRetrievalStatement, 10);
	minimumXPosition = sqlite3_column_double(moleculeRetrievalStatement, 11);
	minimumYPosition = sqlite3_column_double(moleculeRetrievalStatement, 12);
	minimumZPosition = sqlite3_column_double(moleculeRetrievalStatement, 13);
	maximumXPosition = sqlite3_column_double(moleculeRetrievalStatement, 14);
	maximumYPosition = sqlite3_column_double(moleculeRetrievalStatement, 15);
	maximumZPosition = sqlite3_column_double(moleculeRetrievalStatement, 16);
	
	scaleAdjustmentForX = 1.5 / (maximumXPosition - minimumXPosition);
	scaleAdjustmentForY = 1.5 / (maximumYPosition - minimumYPosition);
	scaleAdjustmentForZ = (1.5 * 1.25) / (maximumZPosition - minimumZPosition);
	if (scaleAdjustmentForY < scaleAdjustmentForX)
		scaleAdjustmentForX = scaleAdjustmentForY;
	if (scaleAdjustmentForZ < scaleAdjustmentForX)
		scaleAdjustmentForX = scaleAdjustmentForZ;
		
	return self;
}

- (void)deleteMolecule;
{
	[self deleteMoleculeDataFromDatabase];

	// Remove the file from disk
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


+ (BOOL)isFiletypeSupportedForFile:(NSString *)filePath;
{
	// TODO: Make the categories perform a selector to determine whether this file is supported
	if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"pdb"]) // Uncompressed PDB file
	{
		return YES;
	}
	else if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"gz"]) // Gzipped PDB file
	{
		return YES;
	}
	else
	{
		return NO;
	}
}

#pragma mark -
#pragma mark Molecule 3-D geometry generation
+ (void)setBondColor:(GLubyte *)bondColor forResidueType:(SLSResidueType)residueType;
{
	// Bonds are grey by default
	bondColor[0] = 150;
	bondColor[1] = 150;
	bondColor[2] = 150;
	bondColor[3] = 255;

	switch (residueType)
	{
		case ADENINE:
		case DEOXYADENINE:
		{
			bondColor[0] = 160;
			bondColor[1] = 160;
			bondColor[2] = 255;
		}; break;
		case CYTOSINE:
		case DEOXYCYTOSINE:
		{
			bondColor[0] = 255;
			bondColor[1] = 140;
			bondColor[2] = 75;
		}; break;
		case GUANINE:
		case DEOXYGUANINE:
		{
			bondColor[0] = 255;
			bondColor[1] = 112;
			bondColor[2] = 112;
		}; break;
		case URACIL:
		{
			bondColor[0] = 255;
			bondColor[1] = 128;
			bondColor[2] = 128;
		}; break;
		case DEOXYTHYMINE:
		{
			bondColor[0] = 160;
			bondColor[1] = 255;
			bondColor[2] = 160;
		}; break;
		case GLYCINE:
		{
			bondColor[0] = 235;
			bondColor[1] = 235;
			bondColor[2] = 235;
		}; break;
		case ALANINE:
		{
			bondColor[0] = 200;
			bondColor[1] = 200;
			bondColor[2] = 200;
		}; break;
		case VALINE:
		{
			bondColor[0] = 15;
			bondColor[1] = 130;
			bondColor[2] = 15;
		}; break;
		case LEUCINE:
		{
			bondColor[0] = 15;
			bondColor[1] = 130;
			bondColor[2] = 15;
		}; break;
		case ISOLEUCINE:
		{
			bondColor[0] = 15;
			bondColor[1] = 130;
			bondColor[2] = 15;
		}; break;
		case SERINE:
		{
			bondColor[0] = 250;
			bondColor[1] = 150;
			bondColor[2] = 0;
		}; break;
		case CYSTEINE:
		{
			bondColor[0] = 230;
			bondColor[1] = 230;
			bondColor[2] = 0;
		}; break;
		case THREONINE:
		{
			bondColor[0] = 250;
			bondColor[1] = 150;
			bondColor[2] = 0;
		}; break;
		case METHIONINE:
		{
			bondColor[0] = 230;
			bondColor[1] = 230;
			bondColor[2] = 0;
		}; break;
		case PROLINE:
		{
			bondColor[0] = 220;
			bondColor[1] = 150;
			bondColor[2] = 130;
		}; break;
		case PHENYLALANINE:
		{
			bondColor[0] = 50;
			bondColor[1] = 50;
			bondColor[2] = 170;
		}; break;
		case TYROSINE:
		{
			bondColor[0] = 50;
			bondColor[1] = 50;
			bondColor[2] = 170;
		}; break;
		case TRYPTOPHAN:
		{
			bondColor[0] = 180;
			bondColor[1] = 90;
			bondColor[2] = 180;
		}; break;
		case HISTIDINE:
		{
			bondColor[0] = 130;
			bondColor[1] = 130;
			bondColor[2] = 210;
		}; break;
		case LYSINE:
		{
			bondColor[0] = 20;
			bondColor[1] = 90;
			bondColor[2] = 255;
		}; break;
		case ARGININE:
		{
			bondColor[0] = 20;
			bondColor[1] = 90;
			bondColor[2] = 255;
		}; break;
		case ASPARTICACID:
		{
			bondColor[0] = 230;
			bondColor[1] = 10;
			bondColor[2] = 10;
		}; break;
		case GLUTAMICACID:
		{
			bondColor[0] = 230;
			bondColor[1] = 10;
			bondColor[2] = 10;
		}; break;
		case ASPARAGINE:
		{
			bondColor[0] = 0;
			bondColor[1] = 220;
			bondColor[2] = 220;
		}; break;
		case GLUTAMINE:
		{
			bondColor[0] = 0;
			bondColor[1] = 220;
			bondColor[2] = 220;
		}; break;
		case WATER:
		{
			bondColor[0] = 0;
			bondColor[1] = 0;
			bondColor[2] = 255;
		}; break;
		case UNKNOWNRESIDUE:
        default:
		{
			bondColor[0] = 255;
			bondColor[1] = 255;
			bondColor[2] = 255;
		}; break;
	}
}

#pragma mark -
#pragma mark Database methods

+ (BOOL)beginTransactionWithDatabase:(sqlite3 *)database;
{
	const char *sql1 = "BEGIN EXCLUSIVE TRANSACTION";
	sqlite3_stmt *begin_statement;
	if (sqlite3_prepare_v2(database, sql1, -1, &begin_statement, NULL) != SQLITE_OK)
	{
		return NO;
	}
	if (sqlite3_step(begin_statement) != SQLITE_DONE) 
	{
		return NO;
	}
	sqlite3_finalize(begin_statement);
	return YES;
}

+ (BOOL)endTransactionWithDatabase:(sqlite3 *)database;
{
	const char *sql2 = "COMMIT TRANSACTION";
	sqlite3_stmt *commit_statement;
	if (sqlite3_prepare_v2(database, sql2, -1, &commit_statement, NULL) != SQLITE_OK)
	{
		return NO;
	}
	if (sqlite3_step(commit_statement) != SQLITE_DONE) 
	{
		return NO;
	}
	sqlite3_finalize(commit_statement);
	return YES;
}

+ (void)finalizeStatements;
{
	if (insertMoleculeSQLStatement) sqlite3_finalize(insertMoleculeSQLStatement);
	insertMoleculeSQLStatement = nil;
	if (insertMetadataSQLStatement) sqlite3_finalize(insertMetadataSQLStatement);
	insertMetadataSQLStatement = nil;
	if (insertAtomSQLStatement) sqlite3_finalize(insertAtomSQLStatement);
	insertAtomSQLStatement = nil;
	if (insertBondSQLStatement) sqlite3_finalize(insertBondSQLStatement);
	insertBondSQLStatement = nil;
	if (updateMoleculeSQLStatement) sqlite3_finalize(updateMoleculeSQLStatement);
	updateMoleculeSQLStatement = nil;
	if (retrieveMoleculeSQLStatement) sqlite3_finalize(retrieveMoleculeSQLStatement);
	retrieveMoleculeSQLStatement = nil;
	if (retrieveMetadataSQLStatement) sqlite3_finalize(retrieveMetadataSQLStatement);
	retrieveMetadataSQLStatement = nil;
	if (retrieveAtomSQLStatement) sqlite3_finalize(retrieveAtomSQLStatement);
	retrieveAtomSQLStatement = nil;
	if (retrieveBondSQLStatement) sqlite3_finalize(retrieveBondSQLStatement);
	retrieveBondSQLStatement = nil;
	if (deleteMoleculeSQLStatement) sqlite3_finalize(deleteMoleculeSQLStatement);
	deleteMoleculeSQLStatement = nil;
	if (deleteMetadataSQLStatement) sqlite3_finalize(deleteMetadataSQLStatement);
	deleteMetadataSQLStatement = nil;
	if (deleteAtomSQLStatement) sqlite3_finalize(deleteAtomSQLStatement);
	deleteAtomSQLStatement = nil;
	if (deleteBondSQLStatement) sqlite3_finalize(deleteBondSQLStatement);
	deleteBondSQLStatement = nil;
}

// Write this after all parsing is complete
- (void)writeMoleculeDataToDatabase;
{
	if (updateMoleculeSQLStatement == nil) 
	{
		const char *sql = "UPDATE molecules SET title=?, compound=?, format=?, atom_count=?, bond_count=?, structure_count=?, centerofmass_x=?, centerofmass_y=?, centerofmass_z=?, minimumposition_x=?, minimumposition_y=?, minimumposition_z=?, maximumposition_x=?, maximumposition_y=?, maximumposition_z=? WHERE id=?";
		if (sqlite3_prepare_v2(database, sql, -1, &updateMoleculeSQLStatement, NULL) != SQLITE_OK) 
			NSAssert1(0, NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
	}
	// Bind the query variables.
	sqlite3_bind_text(updateMoleculeSQLStatement, 1, [[title stringByReplacingOccurrencesOfString:@"'" withString:@"''"] UTF8String], -1, SQLITE_TRANSIENT);
	sqlite3_bind_text(updateMoleculeSQLStatement, 2, [[compound stringByReplacingOccurrencesOfString:@"'" withString:@"''"] UTF8String], -1, SQLITE_TRANSIENT);
	sqlite3_bind_int(updateMoleculeSQLStatement, 3, 0); // Format enum is unused right now
	sqlite3_bind_int(updateMoleculeSQLStatement, 4, numberOfAtoms);
	sqlite3_bind_int(updateMoleculeSQLStatement, 5, numberOfBonds);
	sqlite3_bind_int(updateMoleculeSQLStatement, 6, numberOfStructures);
	sqlite3_bind_double(updateMoleculeSQLStatement, 7, centerOfMassInX);
	sqlite3_bind_double(updateMoleculeSQLStatement, 8, centerOfMassInY);
	sqlite3_bind_double(updateMoleculeSQLStatement, 9, centerOfMassInZ);
	sqlite3_bind_double(updateMoleculeSQLStatement, 10, minimumXPosition);
	sqlite3_bind_double(updateMoleculeSQLStatement, 11, minimumYPosition);
	sqlite3_bind_double(updateMoleculeSQLStatement, 12, minimumZPosition);
	sqlite3_bind_double(updateMoleculeSQLStatement, 13, maximumXPosition);
	sqlite3_bind_double(updateMoleculeSQLStatement, 14, maximumYPosition);
	sqlite3_bind_double(updateMoleculeSQLStatement, 15, maximumZPosition);
	sqlite3_bind_int(updateMoleculeSQLStatement, 16, databaseKey);

	// Execute the query.
	int success = sqlite3_step(updateMoleculeSQLStatement);
	// Reset the query for the next use.
	sqlite3_reset(updateMoleculeSQLStatement);
	// Handle errors.
	if (success != SQLITE_DONE) 
		NSAssert1(0, NSLocalizedStringFromTable(@"Error: failed to dehydrate with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));	
}

- (void)addMetadataToDatabase:(NSString *)metadata type:(SLSMetadataType)metadataType;
{
	if (insertMetadataSQLStatement == nil) 
	{
        static char *sql = "INSERT INTO metadata (molecule,type,value) VALUES(?,?,?)";
        if (sqlite3_prepare_v2(database, sql, -1, &insertMetadataSQLStatement, NULL) != SQLITE_OK) 
		{
            NSAssert1(0,NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
        }
    }
	// Bind the query variables.
	sqlite3_bind_int(insertMetadataSQLStatement, 1, databaseKey);
	sqlite3_bind_int(insertMetadataSQLStatement, 2, metadataType);
	sqlite3_bind_text(insertMetadataSQLStatement, 3, [[metadata stringByReplacingOccurrencesOfString:@"'" withString:@"''"] UTF8String], -1, SQLITE_TRANSIENT);
    int success = sqlite3_step(insertMetadataSQLStatement);
    // Because we want to reuse the statement, we "reset" it instead of "finalizing" it.
    sqlite3_reset(insertMetadataSQLStatement);
	if (success != SQLITE_DONE) 
		NSAssert1(0,NSLocalizedStringFromTable(@"Error: failed to insert metadata with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));		
}

- (NSInteger)addAtomToDatabase:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint structureNumber:(NSInteger)structureNumber residueKey:(SLSResidueType)residueKey;
{
	if (insertAtomSQLStatement == nil) 
	{
        static char *sql = "INSERT INTO atoms (molecule,residue,structure,element,x,y,z) VALUES(?,?,?,?,?,?,?)";
        if (sqlite3_prepare_v2(database, sql, -1, &insertAtomSQLStatement, NULL) != SQLITE_OK) 
		{
            NSAssert1(0,NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
        }
    }
	// Bind the query variables.
	sqlite3_clear_bindings(insertAtomSQLStatement);
	sqlite3_bind_int(insertAtomSQLStatement, 1, databaseKey);
	sqlite3_bind_int(insertAtomSQLStatement, 2, residueKey);
	sqlite3_bind_int(insertAtomSQLStatement, 3, structureNumber);
	sqlite3_bind_int(insertAtomSQLStatement, 4, atomType);
	sqlite3_bind_double(insertAtomSQLStatement, 5, (double)newPoint.x);
	sqlite3_bind_double(insertAtomSQLStatement, 6, (double)newPoint.y);
	sqlite3_bind_double(insertAtomSQLStatement, 7, (double)newPoint.z);
    int success = sqlite3_step(insertAtomSQLStatement);
    // Because we want to reuse the statement, we "reset" it instead of "finalizing" it.
    sqlite3_reset(insertAtomSQLStatement);
    if (success == SQLITE_ERROR) 
	{
		return -1;
        // SQLite provides a method which retrieves the value of the most recently auto-generated primary key sequence
        // in the database. To access this functionality, the table should have a column declared of type 
        // "INTEGER PRIMARY KEY"
    }
	
	if (stillCountingAtomsInFirstStructure)
		numberOfAtoms++;

	return sqlite3_last_insert_rowid(database);
}

// Evaluate using atom IDs here for greater rendering flexibility
- (void)addBondToDatabaseWithStartPoint:(NSValue *)startValue endPoint:(NSValue *)endValue bondType:(SLSBondType)bondType structureNumber:(NSInteger)structureNumber residueKey:(NSInteger)residueKey;
{
	SLS3DPoint startPoint, endPoint;
	if ( (startValue == nil) || (endValue == nil) )
		return;
	[startValue getValue:&startPoint];
	[endValue getValue:&endPoint];

	float bondLength = sqrt((startPoint.x - endPoint.x) * (startPoint.x - endPoint.x) + (startPoint.y - endPoint.y) * (startPoint.y - endPoint.y) + (startPoint.z - endPoint.z) * (startPoint.z - endPoint.z));
	if (bondLength > BOND_LENGTH_LIMIT)
	{
		// Don't allow weird, wrong bonds to be displayed
		return;
	}
	
	if (insertBondSQLStatement == nil) 
	{
        static char *sql = "INSERT INTO bonds (molecule,residue,structure,bond_type,start_x,start_y,start_z,end_x,end_y,end_z) VALUES(?,?,?,?,?,?,?,?,?,?)";
        if (sqlite3_prepare_v2(database, sql, -1, &insertBondSQLStatement, NULL) != SQLITE_OK) 
		{
            NSAssert1(0, NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
        }
    }
	// Bind the query variables.
	sqlite3_clear_bindings(insertBondSQLStatement);
	sqlite3_bind_int(insertBondSQLStatement, 1, databaseKey);
	sqlite3_bind_int(insertBondSQLStatement, 2, residueKey);
	sqlite3_bind_int(insertBondSQLStatement, 3, structureNumber);
	sqlite3_bind_int(insertBondSQLStatement, 4, bondType);
	sqlite3_bind_double(insertBondSQLStatement, 5, (double)startPoint.x);
	sqlite3_bind_double(insertBondSQLStatement, 6, (double)startPoint.y);
	sqlite3_bind_double(insertBondSQLStatement, 7, (double)startPoint.z);
	sqlite3_bind_double(insertBondSQLStatement, 8, (double)endPoint.x);
	sqlite3_bind_double(insertBondSQLStatement, 9, (double)endPoint.y);
	sqlite3_bind_double(insertBondSQLStatement, 10, (double)endPoint.z);
    int success = sqlite3_step(insertBondSQLStatement);
    // Because we want to reuse the statement, we "reset" it instead of "finalizing" it.
    sqlite3_reset(insertBondSQLStatement);
	if (success != SQLITE_DONE) 
		NSAssert1(0, NSLocalizedStringFromTable(@"Error: failed to insert bond with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));		

	if (stillCountingAtomsInFirstStructure)
		numberOfBonds++;
}

- (void)readMetadataFromDatabaseIfNecessary;
{	
	// Check to make sure metadata has not already been loaded
	if (isPopulatedFromDatabase)
		return;
	
	if (retrieveMetadataSQLStatement == nil) 
	{
		const char *sql = "SELECT * FROM metadata WHERE molecule=?";
		if (sqlite3_prepare_v2(database, sql, -1, &retrieveMetadataSQLStatement, NULL) != SQLITE_OK) 
		{
            NSAssert1(0,NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
        }
	}
	
	// Bind the query variables.
	sqlite3_bind_int(retrieveMetadataSQLStatement, 1, databaseKey);

	while (sqlite3_step(retrieveMetadataSQLStatement) == SQLITE_ROW) 
	{
		//id, molecule,type,value
		SLSMetadataType metadataType = sqlite3_column_int(retrieveMetadataSQLStatement, 2);
        char *stringResult = (char *)sqlite3_column_text(retrieveMetadataSQLStatement, 3);
		NSString *sqlString =  (stringResult) ? [NSString stringWithUTF8String:stringResult]  : @"";
		
		switch (metadataType)
		{
			case MOLECULESOURCE:  
			{
				source = [sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"];
			}; break;
			case MOLECULEAUTHOR:  
			{
				author = [sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"];
			}; break;
			case JOURNALAUTHOR:  
			{
				journalAuthor = [sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"];
			}; break;
			case JOURNALTITLE:  
			{
				journalTitle = [sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"];
			}; break;
			case JOURNALREFERENCE:  
			{
				journalReference = [sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"];
			}; break;
			case MOLECULESEQUENCE:  
			{
				sequence = [sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"];
			}; break;
		}
	}
	
	// Because we want to reuse the statement, we "reset" it instead of "finalizing" it.
    sqlite3_reset(retrieveMetadataSQLStatement);
    isPopulatedFromDatabase = YES;
}

- (void)deleteMoleculeDataFromDatabase;
{
	// Delete the molecule from the SQLite database
	if (deleteMoleculeSQLStatement == nil) 
	{
		const char *sql = "DELETE FROM molecules WHERE id=?";
		if (sqlite3_prepare_v2(database, sql, -1, &deleteMoleculeSQLStatement, NULL) != SQLITE_OK) 
			NSAssert1(0, NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
	}
	sqlite3_bind_int(deleteMoleculeSQLStatement, 1, databaseKey);
	int success = sqlite3_step(deleteMoleculeSQLStatement);
	sqlite3_reset(deleteMoleculeSQLStatement);
	if (success != SQLITE_DONE) 
		NSAssert1(0,NSLocalizedStringFromTable(@"Error: failed to dehydrate with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));	

	// Delete the metadata associated with the molecule from the SQLite database	
	if (deleteMetadataSQLStatement == nil) 
	{
		const char *sql = "DELETE FROM metadata WHERE molecule=?";
		if (sqlite3_prepare_v2(database, sql, -1, &deleteMetadataSQLStatement, NULL) != SQLITE_OK) 
			NSAssert1(0, NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
	}
	sqlite3_bind_int(deleteMetadataSQLStatement, 1, databaseKey);
	success = sqlite3_step(deleteMetadataSQLStatement);
	sqlite3_reset(deleteMetadataSQLStatement);
	if (success != SQLITE_DONE) 
		NSAssert1(0,NSLocalizedStringFromTable(@"Error: failed to dehydrate with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));	

	// Delete the atoms associated with the molecule from the SQLite database	
	if (deleteAtomSQLStatement == nil) 
	{
		const char *sql = "DELETE FROM atoms WHERE molecule=?";
		if (sqlite3_prepare_v2(database, sql, -1, &deleteAtomSQLStatement, NULL) != SQLITE_OK) 
			NSAssert1(0, NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
	}
	sqlite3_bind_int(deleteAtomSQLStatement, 1, databaseKey);
	success = sqlite3_step(deleteAtomSQLStatement);
	sqlite3_reset(deleteAtomSQLStatement);
	if (success != SQLITE_DONE) 
		NSAssert1(0,NSLocalizedStringFromTable(@"Error: failed to dehydrate with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));	
	
	// Delete the bonds associated with the molecule from the SQLite database	
	if (deleteBondSQLStatement == nil) 
	{
		const char *sql = "DELETE FROM bonds WHERE molecule=?";
		if (sqlite3_prepare_v2(database, sql, -1, &deleteBondSQLStatement, NULL) != SQLITE_OK) 
			NSAssert1(0, NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
	}
	sqlite3_bind_int(deleteBondSQLStatement, 1, databaseKey);
	success = sqlite3_step(deleteBondSQLStatement);
	sqlite3_reset(deleteBondSQLStatement);
	if (success != SQLITE_DONE) 
		NSAssert1(0, NSLocalizedStringFromTable(@"Error: failed to dehydrate with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));		
	
}

- (NSInteger)countAtomsForFirstStructure;
{
    const char *sql = "SELECT COUNT(*) FROM atoms WHERE molecule=? AND structure=?";
	sqlite3_stmt *atomCountingStatement;

    unsigned int totalAtomCount = 0;
    
	if (sqlite3_prepare_v2(database, sql, -1, &atomCountingStatement, NULL) == SQLITE_OK) 
	{
        sqlite3_bind_int(atomCountingStatement, 1, databaseKey);
        sqlite3_bind_int(atomCountingStatement, 2, numberOfStructureBeingDisplayed);
        
        if (sqlite3_step(atomCountingStatement) == SQLITE_ROW)
        {
            totalAtomCount =  sqlite3_column_int(atomCountingStatement, 0);
        }
        else
        {
        }
	}
	sqlite3_finalize(atomCountingStatement);
    
    return totalAtomCount;
}

- (NSInteger)countBondsForFirstStructure;
{
    const char *sql = "SELECT COUNT(*) FROM bonds WHERE molecule=? AND structure=?";
	sqlite3_stmt *bondCountingStatement;
    
    unsigned int totalBondCount = 0;
    
	if (sqlite3_prepare_v2(database, sql, -1, &bondCountingStatement, NULL) == SQLITE_OK) 
	{
        sqlite3_bind_int(bondCountingStatement, 1, databaseKey);
        sqlite3_bind_int(bondCountingStatement, 2, numberOfStructureBeingDisplayed);
        
        if (sqlite3_step(bondCountingStatement) == SQLITE_ROW)
        {
            totalBondCount =  sqlite3_column_int(bondCountingStatement, 0);
        }
        else
        {
        }
	}
	sqlite3_finalize(bondCountingStatement);
    
    return totalBondCount;
}

#pragma mark -
#pragma mark Status notification methods

- (void)showStatusIndicator;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kSLSMoleculeRenderingStartedNotification object:nil ];
}

- (void)updateStatusIndicator;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kSLSMoleculeRenderingUpdateNotification object:[NSNumber numberWithDouble:(double)currentFeatureBeingRendered/(double)totalNumberOfFeaturesToRender] ];
}

- (void)hideStatusIndicator;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kSLSMoleculeRenderingEndedNotification object:nil ];
}

#pragma mark -
#pragma mark Rendering

- (void)switchToDefaultVisualizationMode;
{
    if ((numberOfAtoms < 600) && (numberOfBonds > 0))
    {
//        self.currentVisualizationType = SPACEFILLING;
        self.currentVisualizationType = BALLANDSTICK;
    }
    else
    {
        self.currentVisualizationType = SPACEFILLING;
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:currentVisualizationType forKey:@"currentVisualizationMode"];
}

- (BOOL)renderMolecule:(SLSOpenGLESRenderer *)openGLESRenderer;
{
    currentRenderer = openGLESRenderer;
	@autoreleasepool {
    
		isDoneRendering = NO;
		[self performSelectorOnMainThread:@selector(showStatusIndicator) withObject:nil waitUntilDone:NO];
    
    [openGLESRenderer initiateMoleculeRendering];
    
    openGLESRenderer.overallMoleculeScaleFactor = scaleAdjustmentForX;

		currentFeatureBeingRendered = 0;
    
		switch(currentVisualizationType)
		{
			case BALLANDSTICK:
			{
            [openGLESRenderer configureBasedOnNumberOfAtoms:[self countAtomsForFirstStructure] numberOfBonds:[self countBondsForFirstStructure]];
				totalNumberOfFeaturesToRender = numberOfAtoms + numberOfBonds;

            openGLESRenderer.bondRadiusScaleFactor = 0.15;
            openGLESRenderer.atomRadiusScaleFactor = 0.35;
				
				[self readAndRenderAtoms:openGLESRenderer];
				[self readAndRenderBonds:openGLESRenderer];
//            openGLESRenderer.atomRadiusScaleFactor = 0.27;
			}; break;
			case SPACEFILLING:
			{
            [openGLESRenderer configureBasedOnNumberOfAtoms:[self countAtomsForFirstStructure] numberOfBonds:0];
				totalNumberOfFeaturesToRender = numberOfAtoms;

            openGLESRenderer.atomRadiusScaleFactor = 1.0;
            [self readAndRenderAtoms:openGLESRenderer];
			}; break;
			case CYLINDRICAL:
			{
            [openGLESRenderer configureBasedOnNumberOfAtoms:0 numberOfBonds:[self countBondsForFirstStructure]];

				totalNumberOfFeaturesToRender = numberOfBonds;

            openGLESRenderer.bondRadiusScaleFactor = 0.15;
				[self readAndRenderBonds:openGLESRenderer];
			}; break;
		}
		
		if (!isRenderingCancelled)
		{
        [openGLESRenderer bindVertexBuffersForMolecule];
//        }
//        else
//        {
//            [openGLESRenderer performSelectorOnMainThread:@selector(bindVertexBuffersForMolecule) withObject:nil waitUntilDone:YES];   
//        }		
		}
		else
		{
        isBeingDisplayed = NO;
        isRenderingCancelled = NO;
        
        [openGLESRenderer terminateMoleculeRendering];
		}
		
    
		isDoneRendering = YES;
		[self performSelectorOnMainThread:@selector(hideStatusIndicator) withObject:nil waitUntilDone:YES];
    
	}
    
    currentRenderer = nil;
	return YES;
}

- (void)readAndRenderAtoms:(SLSOpenGLESRenderer *)openGLESRenderer;
{	
	if (isRenderingCancelled)
    {
		return;
    }
    
	if (retrieveAtomSQLStatement == nil) 
	{
		const char *sql = "SELECT residue,structure,element,x,y,z FROM atoms WHERE molecule=? AND structure=?";
        //		const char *sql = "SELECT * FROM atoms WHERE molecule=?";
		if (sqlite3_prepare_v2(database, sql, -1, &retrieveAtomSQLStatement, NULL) != SQLITE_OK) 
		{
            NSAssert1(0, NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
        }
	}
	
	// Bind the query variables.
	sqlite3_bind_int(retrieveAtomSQLStatement, 1, databaseKey);
	sqlite3_bind_int(retrieveAtomSQLStatement, 2, numberOfStructureBeingDisplayed);
    	
    while ((sqlite3_step(retrieveAtomSQLStatement) == SQLITE_ROW) && !isRenderingCancelled)
	{
		//(id,molecule,residue,structure,element,x,y,z);"
		if ( (currentFeatureBeingRendered % 100) == 0)
        {
			[self performSelectorOnMainThread:@selector(updateStatusIndicator) withObject:nil waitUntilDone:NO];
        }
		currentFeatureBeingRendered++;		
        
		SLSResidueType residueType = sqlite3_column_int(retrieveAtomSQLStatement, 0);
		// TODO: Determine if rendering a particular structure, if not don't render atom 
		SLSAtomType atomType = sqlite3_column_int(retrieveAtomSQLStatement, 2);
		SLS3DPoint atomCoordinate;
		atomCoordinate.x = sqlite3_column_double(retrieveAtomSQLStatement, 3);
		atomCoordinate.x -= centerOfMassInX;
		atomCoordinate.x *= scaleAdjustmentForX;
		atomCoordinate.y = sqlite3_column_double(retrieveAtomSQLStatement, 4);
		atomCoordinate.y -= centerOfMassInY;
		atomCoordinate.y *= scaleAdjustmentForX;
		atomCoordinate.z = sqlite3_column_double(retrieveAtomSQLStatement, 5);
		atomCoordinate.z -= centerOfMassInZ;
		atomCoordinate.z *= scaleAdjustmentForX;
		
		if (residueType != WATER)
        {
//			[openGLESRenderer addAtomToVertexBuffers:OXYGEN atPoint:atomCoordinate];
			[openGLESRenderer addAtomToVertexBuffers:atomType atPoint:atomCoordinate];
        }
	}
	
	// Because we want to reuse the statement, we "reset" it instead of "finalizing" it.
    sqlite3_reset(retrieveAtomSQLStatement);
}

- (void)readAndRenderBonds:(SLSOpenGLESRenderer *)openGLESRenderer;
{
	if (isRenderingCancelled)
    {
		return;
    }
	
	if (retrieveBondSQLStatement == nil) 
	{
		const char *sql = "SELECT * FROM bonds WHERE molecule=? AND structure=?";
		if (sqlite3_prepare_v2(database, sql, -1, &retrieveBondSQLStatement, NULL) != SQLITE_OK) 
		{
            NSAssert1(0, NSLocalizedStringFromTable(@"Error: failed to prepare statement with message '%s'.", @"Localized", nil), sqlite3_errmsg(database));
        }
	}
	
	// Bind the query variables.
	sqlite3_bind_int(retrieveBondSQLStatement, 1, databaseKey);
	sqlite3_bind_int(retrieveBondSQLStatement, 2, numberOfStructureBeingDisplayed);
    
	while ((sqlite3_step(retrieveBondSQLStatement) == SQLITE_ROW) && !isRenderingCancelled)
	{
		//(id ,molecule ,residue ,structure ,bond_type ,start_x ,start_y ,start_z ,end_x ,end_y ,end_z )
		
		// TODO: Determine if rendering a particular structure, if not don't render atom 
		if ( (currentFeatureBeingRendered % 100) == 0)
			[self performSelectorOnMainThread:@selector(updateStatusIndicator) withObject:nil waitUntilDone:NO];
		currentFeatureBeingRendered++;		
		
		SLSBondType bondType = sqlite3_column_int(retrieveBondSQLStatement, 4);
		SLS3DPoint startingCoordinate, endingCoordinate;
		startingCoordinate.x = sqlite3_column_double(retrieveBondSQLStatement, 5);
		startingCoordinate.x -= centerOfMassInX;
		startingCoordinate.x *= scaleAdjustmentForX;
		startingCoordinate.y = sqlite3_column_double(retrieveBondSQLStatement, 6);
		startingCoordinate.y -= centerOfMassInY;
		startingCoordinate.y *= scaleAdjustmentForX;
		startingCoordinate.z = sqlite3_column_double(retrieveBondSQLStatement, 7);
		startingCoordinate.z -= centerOfMassInZ;
		startingCoordinate.z *= scaleAdjustmentForX;
		endingCoordinate.x = sqlite3_column_double(retrieveBondSQLStatement, 8);
		endingCoordinate.x -= centerOfMassInX;
		endingCoordinate.x *= scaleAdjustmentForX;
		endingCoordinate.y = sqlite3_column_double(retrieveBondSQLStatement, 9);
		endingCoordinate.y -= centerOfMassInY;
		endingCoordinate.y *= scaleAdjustmentForX;
		endingCoordinate.z = sqlite3_column_double(retrieveBondSQLStatement, 10);
		endingCoordinate.z -= centerOfMassInZ;
		endingCoordinate.z *= scaleAdjustmentForX;
		SLSResidueType residueType = sqlite3_column_int(retrieveBondSQLStatement, 2);		
		GLubyte bondColor[4] = {200,200,200,255};  // Bonds are grey by default
        
		if (currentVisualizationType == CYLINDRICAL)
        {
			[SLSMolecule setBondColor:bondColor forResidueType:residueType];
        }
        
		if (residueType != WATER)
        {
			[openGLESRenderer addBondToVertexBuffersWithStartPoint:startingCoordinate endPoint:endingCoordinate bondColor:bondColor bondType:bondType];
        }
	}
	
	// Because we want to reuse the statement, we "reset" it instead of "finalizing" it.
    sqlite3_reset(retrieveBondSQLStatement);
}


#pragma mark -
#pragma mark Accessors

@synthesize centerOfMassInX, centerOfMassInY, centerOfMassInZ;
@synthesize filename, filenameWithoutExtension, title, keywords, journalAuthor, journalTitle, journalReference, sequence, compound, source, author;
@synthesize isBeingDisplayed, isDoneRendering, isRenderingCancelled;
@synthesize numberOfAtoms, numberOfStructures;
@synthesize previousTerminalAtomValue;
@synthesize currentVisualizationType;
@synthesize numberOfStructureBeingDisplayed;


- (void)setIsBeingDisplayed:(BOOL)newValue;
{
	if (newValue == isBeingDisplayed)
    {
		return;
    }
    
	isBeingDisplayed = newValue;
	if (isBeingDisplayed)
	{
		isRenderingCancelled = NO;
	}
	else
	{
		if (!isDoneRendering)
		{
			self.isRenderingCancelled = YES;
            [currentRenderer cancelMoleculeRendering];
			[NSThread sleepForTimeInterval:1.0];
		}
	}
}

@end
