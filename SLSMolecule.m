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

// TODO: do a define to switch normal, index type
#pragma mark -
#pragma mark Icosahedron tables

// These are from the OpenGL documentation at www.opengl.org
#define X .525731112119133606 
#define Z .850650808352039932

static GLfloat vdata[12][3] = 
{    
	{-X, 0.0f, Z}, 
	{0.0f, Z, X}, 
	{X, 0.0f, Z}, 
	{-Z, X, 0.0f}, 	
	{0.0f, Z, -X}, 
	{Z, X, 0.0f}, 
	{Z, -X, 0.0f}, 
	{X, 0.0f, -Z},
	{-X, 0.0f, -Z},
	{0.0f, -Z, -X},
    {0.0f, -Z, X},
	{-Z, -X, 0.0f} 
};

static GLushort tindices[20][3] = 
{ 
	{0,1,2},
	{0,3,1},
	{3,4,1},
	{1,4,5},
	{1,5,2},    
	{5,6,2},
	{5,7,6},
	{4,7,5},
	{4,8,7},
	{8,9,7},    
	{9,6,7},
	{9,10,6},
	{9,11,10},
	{11,0,10},
	{0,2,10}, 
	{10,2,6},
	{3,0,11},
	{3,11,8},
	{3,8,4},
	{9,8,11} 
};

/*static GLfloat vdata[12][3] = 
{    
	{-X, 0.0f, Z}, 
	{X, 0.0f, Z}, 
	{-X, 0.0f, -Z}, 
	{X, 0.0f, -Z},    
	{0.0f, Z, X}, 
	{0.0f, Z, -X}, 
	{0.0f, -Z, X}, 
	{0.0f, -Z, -X},    
	{Z, X, 0.0f}, 
	{-Z, X, 0.0f}, 
	{Z, -X, 0.0f}, 
	{-Z, -X, 0.0f} 
};

static GLushort tindices[20][3] = 
{ 
	{0,4,1},
	{0,9,4},
	{9,5,4},
	{4,5,8},
	{4,8,1},    
	{8,10,1},
	{8,3,10},
	{5,3,8},
	{5,2,3},
	{2,7,3},    
	{7,10,3},
	{7,6,10},
	{7,11,6},
	{11,0,6},
	{0,1,6}, 
	{6,1,10},
	{9,0,11},
	{9,11,2},
	{9,2,5},
	{7,2,11} 
};*/

#pragma mark -
#pragma mark Bond edge tables

static GLfloat bondEdges[4][3] = 
{ 
	{0,1,0}, {0,0,1}, {0,-1,0}, {0,0,-1} 
};

static GLushort bondIndices[8][3] = 
{
//	{0,4,1}, {4,5,1}, {1,5,2}, {5,6,2}, {6,7,2}, {2,7,3}, {3,7,0}, {7,4,0}
	{0,1,2}, {1,3,2}, {2,3,4}, {3,5,4}, {5,7,4}, {4,7,6}, {6,7,0}, {7,1,0}
};


#pragma mark -
#pragma mark OpenGL helper functions

void normalize(GLfloat *v) 
{    
	GLfloat d = sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]); 
	v[0] /= d; 
	v[1] /= d; 
	v[2] /= d; 
}

#pragma mark -
#pragma mark Initialization and deallocation

- (id)init;
{
	if (![super init])
		return nil;
	
	m_numVertices = 0;
	m_numIndices = 0;
	m_numberOfVertexBuffers = 0;
	m_vertexArray = nil;
	m_numberOfIndicesForBuffers = NULL;
	totalNumberOfVertices = 0;
	totalNumberOfTriangles = 0;
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
	
	m_vertexBufferHandle = NULL;
	m_indexBufferHandle = NULL;
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

- (id)initWithFilename:(NSString *)newFilename database:(sqlite3 *)newDatabase;
{
	if (![self init])
		return nil;

	database = newDatabase;
	filename = [newFilename copy];
	
	NSRange rangeUntilFirstPeriod = [filename rangeOfString:@"."];
	if (rangeUntilFirstPeriod.location == NSNotFound)
		filenameWithoutExtension = filename;
	else
		filenameWithoutExtension = [[filename substringToIndex:rangeUntilFirstPeriod.location] retain];	
	
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
	
	
	// TODO: Determine filetype, set up selector to match
	// Write the format as an integer
	NSError *error = nil;
	if (![self readFromPDBFileToDatabase:&error])
	{
		return nil;
	}
	
	return self;
}

- (id)initWithSQLStatement:(sqlite3_stmt *)moleculeRetrievalStatement database:(sqlite3 *)newDatabase;
{
	if (![self init])
		return nil;

	database = newDatabase;
	
	// Retrieve molecule information from the line of the SELECT statement
	//(id,filename,title,compound,format,atom_count,structure_count, centerofmass_x,centerofmass_y,centerofmass_z,minimumposition_x,minimumposition_y,minimumposition_z,maximumposition_x,maximumposition_y,maximumposition_z)
	databaseKey = sqlite3_column_int(moleculeRetrievalStatement, 0);
	char *stringResult = (char *)sqlite3_column_text(moleculeRetrievalStatement, 1);
	NSString *sqlString =  (stringResult) ? [NSString stringWithUTF8String:stringResult]  : @"";
	filename = [[sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"] retain];
	
	NSRange rangeUntilFirstPeriod = [filename rangeOfString:@"."];
	if (rangeUntilFirstPeriod.location == NSNotFound)
		filenameWithoutExtension = filename;
	else
		filenameWithoutExtension = [[filename substringToIndex:rangeUntilFirstPeriod.location] retain];
	
	stringResult = (char *)sqlite3_column_text(moleculeRetrievalStatement, 2);
	sqlString =  (stringResult) ? [NSString stringWithUTF8String:stringResult]  : @"";
	title = [[sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"] retain];

	stringResult = (char *)sqlite3_column_text(moleculeRetrievalStatement, 3);
	sqlString =  (stringResult) ? [NSString stringWithUTF8String:stringResult]  : @"";
	compound = [[sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"] retain];
	
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
	scaleAdjustmentForZ = 1.5 / (maximumZPosition - minimumZPosition);
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
													   delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"Localized", nil) otherButtonTitles: nil];
		[alert show];
		[alert release];					
		return;
	}
}

- (void)dealloc;
{
	// All buffers are deallocated after they are bound to their OpenGL counterparts,
	// but we still need to delete the OpenGL buffers themselves when done
	if (m_numberOfIndicesForBuffers != NULL)
	{
		free(m_numberOfIndicesForBuffers);
//		m_numberOfVertexBuffers = NULL;
	}

	if (m_vertexBufferHandle != NULL)
		[self freeVertexBuffers];
	[m_vertexArrays release];
	[m_indexArrays release];
	[m_vertexArray release];
	[m_indexArray release];
	
	
	[title release];
	[filename release];
	[filenameWithoutExtension release];
	[keywords release];
	[journalAuthor release];
	[journalTitle release];
	[journalReference release];
	[sequence release];
	[compound release];
	[source release];
	[author release];
	[previousTerminalAtomValue release];

	[super dealloc];
}

+ (BOOL)isFiletypeSupportedForFile:(NSString *)filePath;
{
	// TODO: Make the categories perform a selector to determine whether this file is supported
	if ([[filePath pathExtension] isEqualToString:@"pdb"]) // Uncompressed PDB file
		return YES;
	else if ([[filePath pathExtension] isEqualToString:@"gz"]) // Gzipped PDB file
		return YES;
	else
		return NO;
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
	}
}

- (void)addNormal:(GLfloat *)newNormal;
{
	GLshort shortNormals[4];
	shortNormals[0] = (GLshort)round(newNormal[0] * 32767.0f);
	
	shortNormals[1] = (GLshort)round(newNormal[1] * 32767.0f);
	shortNormals[2] = (GLshort)round(newNormal[2] * 32767.0f);
	shortNormals[3] = 0;
	
	[m_vertexArray appendBytes:shortNormals length:(sizeof(GLshort) * 4)];	
//	[m_vertexArray appendBytes:newNormal length:(sizeof(GLfloat) * 3)];	
}

- (void)addVertex:(GLfloat *)newVertex;
{
	GLshort shortVertex[4];
	shortVertex[0] = (GLshort)round(newVertex[0] * 32767.0f);
	shortVertex[1] = (GLshort)round(newVertex[1] * 32767.0f);
	shortVertex[2] = (GLshort)round(newVertex[2] * 32767.0f);
	shortVertex[3] = 0;
	
	if ( ((newVertex[0] < -1.0f) || (newVertex[0] > 1.0f)) || ((newVertex[1] < -1.0f) || (newVertex[1] > 1.0f)) || ((newVertex[2] < -1.0f) || (newVertex[2] > 1.0f)) )
	{
		NSLog(@"Vertex outside range: %f, %f, %f", newVertex[0], newVertex[1], newVertex[2]);
	}
	
	[m_vertexArray appendBytes:shortVertex length:(sizeof(GLshort) * 4)];	

//	[m_vertexArray appendBytes:newVertex length:(sizeof(GLfloat) * 3)];
	m_numVertices++;
	totalNumberOfVertices++;
}

- (void)addIndex:(GLushort *)newIndex;
{
	[m_indexArray appendBytes:newIndex length:sizeof(GLushort)];
	m_numIndices++;
}

- (void)addColor:(GLubyte *)newColor;
{
	[m_vertexArray appendBytes:newColor length:(sizeof(GLubyte) * 4)];
}

- (void)addAtomToVertexBuffers:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint;
{
	GLfloat newVertex[3];
	GLubyte newColor[4];
	GLfloat atomRadius = 0.4f;

	// To avoid an overflow due to OpenGL ES's limit to unsigned short values in index buffers, we need to split vertices into multiple buffers
	if (m_numVertices > 65000)
	{
		[self addVertexBuffer];
	}
	GLushort baseToAddToIndices = m_numVertices;
		
	switch (atomType)
	{
		case CARBON:
		{
			newColor[0] = 144;
			newColor[1] = 144;
			newColor[2] = 144;
			newColor[3] = 255;
			atomRadius = 1.70f; // van der Waals radius
		}; break;
		case HYDROGEN:
		{
			newColor[0] = 255;
			newColor[1] = 255;
			newColor[2] = 255;
			newColor[3] = 255;
			atomRadius = 1.09f;
		}; break;
		case OXYGEN:
		{
			newColor[0] = 240;
			newColor[1] = 0;
			newColor[2] = 0;
			newColor[3] = 255;
			atomRadius = 1.52f;
		}; break;
		case NITROGEN:
		{
			newColor[0] = 48;
			newColor[1] = 80;
			newColor[2] = 248;
			newColor[3] = 255;
			atomRadius = 1.55f;
		}; break;
		case SULFUR:
		{
			newColor[0] = 255;
			newColor[1] = 255;
			newColor[2] = 48;
			newColor[3] = 255;
			atomRadius = 1.80f;
		}; break;
		case PHOSPHOROUS:
		{
			newColor[0] = 255;
			newColor[1] = 128;
			newColor[2] = 0;
			newColor[3] = 255;
			atomRadius = 1.80f;
		}; break;
		case IRON:
		{
			newColor[0] = 224;
			newColor[1] = 102;
			newColor[2] = 51;
			newColor[3] = 255;
			atomRadius = 2.00f;
		}; break;
		case SILICON:
		{
			newColor[0] = 240;
			newColor[1] = 200;
			newColor[2] = 160;
			newColor[3] = 255;
			atomRadius = 1.09f;
		}; break;
		default:
		{ // Use green to highlight missing elements in lookup table
			newColor[0] = 0;
			newColor[1] = 255;
			newColor[2] = 0;
			newColor[3] = 255;
			atomRadius = 1.70f;
		}; break;
	}
	
	// Use a smaller radius for the models in the ball-and-stick visualization
	if (currentVisualizationType == BALLANDSTICK)
		atomRadius = 0.4f;
	
	atomRadius *= scaleAdjustmentForX;

	int currentCounter;
	for (currentCounter = 0; currentCounter < 12; currentCounter++)
	{
		// Adjust radius and shift to match center
		newVertex[0] = (vdata[currentCounter][0] * atomRadius) + newPoint.x;
		newVertex[1] = (vdata[currentCounter][1] * atomRadius) + newPoint.y;
		newVertex[2] = (vdata[currentCounter][2] * atomRadius) + newPoint.z;

		// Add vertex from table
		[self addVertex:newVertex];

		// Just use original icosahedron for normals
		newVertex[0] = vdata[currentCounter][0];
		newVertex[1] = vdata[currentCounter][1];
		newVertex[2] = vdata[currentCounter][2];
		
		// Add sphere normal
		[self addNormal:newVertex];		
		
		// Add a color corresponding to this vertex
		[self addColor:newColor];
	}
	
	GLushort indexHolder;
	for (currentCounter = 0; currentCounter < 20; currentCounter++)
	{
		int internalCounter;
		totalNumberOfTriangles++;
		for (internalCounter = 0; internalCounter < 3; internalCounter++)
		{
			indexHolder = baseToAddToIndices + tindices[currentCounter][internalCounter];
			[self addIndex:&indexHolder];
		}
	}	
}

- (void)addBondToVertexBuffersWithStartPoint:(SLS3DPoint)startPoint endPoint:(SLS3DPoint)endPoint bondColor:(GLubyte *)bondColor bondType:(SLSBondType)bondType;
{
//	SLS3DPoint startPoint, endPoint;
//	if ( (startValue == nil) || (endValue == nil) )
//		return;
//	[startValue getValue:&startPoint];
//	[endValue getValue:&endPoint];

	GLfloat bondRadius = 0.10;
	bondRadius *= scaleAdjustmentForX;

	GLfloat xDifference = endPoint.x - startPoint.x;
	GLfloat yDifference = endPoint.y - startPoint.y;
	GLfloat zDifference = endPoint.z - startPoint.z;
	GLfloat xyHypotenuse = sqrt(xDifference * xDifference + yDifference * yDifference);
	GLfloat xzHypotenuse = sqrt(xDifference * xDifference + zDifference * zDifference);

	// To avoid an overflow due to OpenGL ES's limit to unsigned short values in index buffers, we need to split vertices into multiple buffers
	if (m_numVertices > 65000)
	{
		[self addVertexBuffer];
	}
	GLushort baseToAddToIndices = m_numVertices;
	
	
	// Do first edge vertices, colors, and normals
	unsigned int edgeCounter;
	for (edgeCounter = 0; edgeCounter < 4; edgeCounter++)
	{
		SLS3DPoint calculatedNormal;
		GLfloat edgeNormal[3], edgeVertex[3];
		
		if (xyHypotenuse == 0)
		{
			calculatedNormal.x = bondEdges[edgeCounter][0];
			calculatedNormal.y = bondEdges[edgeCounter][1];
		}
		else
		{
			calculatedNormal.x = bondEdges[edgeCounter][0] * xDifference / xyHypotenuse - bondEdges[edgeCounter][1] * yDifference / xyHypotenuse;
			calculatedNormal.y = bondEdges[edgeCounter][0] * yDifference / xyHypotenuse + bondEdges[edgeCounter][1] * xDifference / xyHypotenuse;
		}

		if (xzHypotenuse == 0)
		{
			calculatedNormal.z = bondEdges[edgeCounter][2];
		}
		else
		{
			calculatedNormal.z = calculatedNormal.x * zDifference / xzHypotenuse + bondEdges[edgeCounter][2] * xDifference / xzHypotenuse;
			calculatedNormal.x = calculatedNormal.x * xDifference / xzHypotenuse - bondEdges[edgeCounter][2] * zDifference / xzHypotenuse;
		}
		
		edgeVertex[0] = (calculatedNormal.x * bondRadius) + startPoint.x;
		edgeVertex[1] = (calculatedNormal.y * bondRadius) + startPoint.y;
		edgeVertex[2] = (calculatedNormal.z * bondRadius) + startPoint.z;
		[self addVertex:edgeVertex];

		edgeNormal[0] = calculatedNormal.x;
		edgeNormal[1] = calculatedNormal.y;
		edgeNormal[2] = calculatedNormal.z;
		
		[self addNormal:edgeNormal];
		[self addColor:bondColor];
		
		edgeVertex[0] = (calculatedNormal.x * bondRadius) + endPoint.x;
		edgeVertex[1] = (calculatedNormal.y * bondRadius) + endPoint.y;
		edgeVertex[2] = (calculatedNormal.z * bondRadius) + endPoint.z;
		[self addVertex:edgeVertex];
		[self addNormal:edgeNormal];
		[self addColor:bondColor];
	}

	int currentCounter;
	for (currentCounter = 0; currentCounter < 8; currentCounter++)
	{
		int internalCounter;
		totalNumberOfTriangles++;

		for (internalCounter = 0; internalCounter < 3; internalCounter++)
		{
			GLushort indexHolder = baseToAddToIndices + bondIndices[currentCounter][internalCounter];
			[self addIndex:&indexHolder];
		}
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
	if (insertMetadataSQLStatement) sqlite3_finalize(insertMetadataSQLStatement);
	if (insertAtomSQLStatement) sqlite3_finalize(insertAtomSQLStatement);
	if (insertBondSQLStatement) sqlite3_finalize(insertBondSQLStatement);
	if (updateMoleculeSQLStatement) sqlite3_finalize(updateMoleculeSQLStatement);
	if (retrieveMoleculeSQLStatement) sqlite3_finalize(retrieveMoleculeSQLStatement);
	if (retrieveMetadataSQLStatement) sqlite3_finalize(retrieveMetadataSQLStatement);
	if (retrieveAtomSQLStatement) sqlite3_finalize(retrieveAtomSQLStatement);
	if (retrieveBondSQLStatement) sqlite3_finalize(retrieveBondSQLStatement);
	if (deleteMoleculeSQLStatement) sqlite3_finalize(deleteMoleculeSQLStatement);
	if (deleteMetadataSQLStatement) sqlite3_finalize(deleteMetadataSQLStatement);
	if (deleteAtomSQLStatement) sqlite3_finalize(deleteAtomSQLStatement);
	if (deleteBondSQLStatement) sqlite3_finalize(deleteBondSQLStatement);
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
				[source release];
				source = [[sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"] retain];
			}; break;
			case MOLECULEAUTHOR:  
			{
				[author release];
				author = [[sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"] retain];
			}; break;
			case JOURNALAUTHOR:  
			{
				[journalAuthor release];
				journalAuthor = [[sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"] retain];
			}; break;
			case JOURNALTITLE:  
			{
				[journalTitle release];
				journalTitle = [[sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"] retain];
			}; break;
			case JOURNALREFERENCE:  
			{
				[journalReference release];
				journalReference = [[sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"] retain];
			}; break;
			case MOLECULESEQUENCE:  
			{
				[sequence release];
				sequence = [[sqlString stringByReplacingOccurrencesOfString:@"''" withString:@"'"] retain];
			}; break;
		}
	}
	
	// Because we want to reuse the statement, we "reset" it instead of "finalizing" it.
    sqlite3_reset(retrieveMetadataSQLStatement);
    isPopulatedFromDatabase = YES;
}

- (void)readAndRenderAtoms;
{	
	if (isRenderingCancelled)
		return;

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
	
	while (sqlite3_step(retrieveAtomSQLStatement) == SQLITE_ROW) 
	{
		if (isRenderingCancelled)
		{
			sqlite3_reset(retrieveAtomSQLStatement);
			return;
		}

		//(id,molecule,residue,structure,element,x,y,z);"
		if ( (currentFeatureBeingRendered % 100) == 0)
			[self performSelectorOnMainThread:@selector(updateStatusIndicator) withObject:nil waitUntilDone:NO];
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
			[self addAtomToVertexBuffers:atomType atPoint:atomCoordinate];
	}
	
	// Because we want to reuse the statement, we "reset" it instead of "finalizing" it.
    sqlite3_reset(retrieveAtomSQLStatement);
}

- (void)readAndRenderBonds;
{
	if (isRenderingCancelled)
		return;
	
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

	while (sqlite3_step(retrieveBondSQLStatement) == SQLITE_ROW) 
	{
		if (isRenderingCancelled)
		{
			sqlite3_reset(retrieveBondSQLStatement);			
			return;
		}

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
			[SLSMolecule setBondColor:bondColor forResidueType:residueType];

		if (residueType != WATER)
			[self addBondToVertexBuffersWithStartPoint:startingCoordinate endPoint:endingCoordinate bondColor:bondColor bondType:bondType];
	}
	
	// Because we want to reuse the statement, we "reset" it instead of "finalizing" it.
    sqlite3_reset(retrieveBondSQLStatement);
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

#pragma mark -
#pragma mark Status notification methods

- (void)showStatusIndicator;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MoleculeRenderingStarted" object:nil ];
}

- (void)updateStatusIndicator;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MoleculeRenderingUpdate" object:[NSNumber numberWithDouble:(double)currentFeatureBeingRendered/(double)totalNumberOfFeaturesToRender] ];
}

- (void)hideStatusIndicator;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MoleculeRenderingEnded" object:nil ];
}

#pragma mark -
#pragma mark OpenGL drawing routines

- (void)addVertexBuffer;
{
	if (m_vertexArray != nil)
	{
		[m_vertexArray release];
		[m_indexArray release];
	}
	m_vertexArray = [[NSMutableData alloc] init];
	m_indexArray = [[NSMutableData alloc] init];
	m_numberOfVertexBuffers++;
	[m_vertexArrays addObject:m_vertexArray];
	[m_indexArrays addObject:m_indexArray];
	m_numVertices = 0;
	m_numIndices = 0;
}

- (BOOL)renderMolecule;
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	isDoneRendering = NO;
	[self performSelectorOnMainThread:@selector(showStatusIndicator) withObject:nil waitUntilDone:NO];

	m_vertexArrays = [[NSMutableArray alloc] init];
	m_indexArrays = [[NSMutableArray alloc] init];

	m_numberOfVertexBuffers = 0;
	[self addVertexBuffer];

	currentFeatureBeingRendered = 0;

	switch(currentVisualizationType)
	{
		case BALLANDSTICK:
		{
			totalNumberOfFeaturesToRender = numberOfAtoms + numberOfBonds;
			
			[self readAndRenderAtoms];
			[self readAndRenderBonds];
		}; break;
		case SPACEFILLING:
		{
			totalNumberOfFeaturesToRender = numberOfAtoms;
			[self readAndRenderAtoms];
		}; break;
		case CYLINDRICAL:
		{
			totalNumberOfFeaturesToRender = numberOfBonds;
			[self readAndRenderBonds];
		}; break;
	}
	
	if (!isRenderingCancelled)
	{
		[self performSelectorOnMainThread:@selector(bindVertexBuffersForMolecule) withObject:nil waitUntilDone:YES];
		
	}
	else
	{
		m_numberOfVertexBuffers = 0;
		
		isBeingDisplayed = NO;
		isRenderingCancelled = NO;
		
		// Release all the NSData arrays that were partially generated
		[m_indexArray release];	
		m_indexArray = nil;
		[m_indexArrays release];
		
		[m_vertexArray release];
		m_vertexArray = nil;
		[m_vertexArrays release];	
		
	}
	

	isDoneRendering = YES;
	[self performSelectorOnMainThread:@selector(hideStatusIndicator) withObject:nil waitUntilDone:NO];

	[pool release];
	return YES;
}

- (void)bindVertexBuffersForMolecule;
{
	m_vertexBufferHandle = (GLuint *) malloc(sizeof(GLuint) * m_numberOfVertexBuffers);
	m_indexBufferHandle = (GLuint *) malloc(sizeof(GLuint) * m_numberOfVertexBuffers);
	if (m_numberOfIndicesForBuffers != NULL)
	{
		free(m_numberOfIndicesForBuffers);
//		m_numberOfVertexBuffers = null;
	}
	
	m_numberOfIndicesForBuffers = (unsigned int *) malloc(sizeof(unsigned int) * m_numberOfVertexBuffers);
	
	unsigned int bufferIndex;
	for (bufferIndex = 0; bufferIndex < m_numberOfVertexBuffers; bufferIndex++)
	{
		glGenBuffers(1, &m_indexBufferHandle[bufferIndex]); 
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_indexBufferHandle[bufferIndex]);   

		NSData *currentIndexBuffer = [m_indexArrays objectAtIndex:bufferIndex];
		GLushort *indexBuffer = (GLushort *)[currentIndexBuffer bytes];
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, [currentIndexBuffer length], indexBuffer, GL_STATIC_DRAW);     

		m_numberOfIndicesForBuffers[bufferIndex] = ([currentIndexBuffer length] / sizeof(GLushort));		
	}	
	// Now that the data is in the OpenGL buffer, can release the NSData

    [m_indexArray release];	
	m_indexArray = nil;
	[m_indexArrays release];
	m_indexArrays = nil;
	
	for (bufferIndex = 0; bufferIndex < m_numberOfVertexBuffers; bufferIndex++)
	{	
		glGenBuffers(1, &m_vertexBufferHandle[bufferIndex]); 
		glBindBuffer(GL_ARRAY_BUFFER, m_vertexBufferHandle[bufferIndex]); 

		NSData *currentVertexBuffer = [m_vertexArrays objectAtIndex:bufferIndex];
		glBufferData(GL_ARRAY_BUFFER, [currentVertexBuffer length], (void *)[currentVertexBuffer bytes], GL_STATIC_DRAW); 

//		glBindBuffer(GL_ARRAY_BUFFER, 0); 
	}
	[m_vertexArray release];
	m_vertexArray = nil;
	[m_vertexArrays release];	
	m_vertexArrays = nil;
}

- (void)drawMolecule;
{
	unsigned int bufferIndex;
	for (bufferIndex = 0; bufferIndex < m_numberOfVertexBuffers; bufferIndex++)
	{
		// Bind the buffers
		glBindBuffer(GL_ARRAY_BUFFER, m_vertexBufferHandle[bufferIndex]); 
		glVertexPointer(3, GL_SHORT, 20, (char *)NULL + 0); 		
		glNormalPointer(GL_SHORT, 20, (char *)NULL + 8); 
		glColorPointer(4, GL_UNSIGNED_BYTE, 20, (char *)NULL + 16);
		
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_indexBufferHandle[bufferIndex]);    

		// Do the actual drawing to the screen
		glDrawElements(GL_TRIANGLES,m_numberOfIndicesForBuffers[bufferIndex],GL_UNSIGNED_SHORT, NULL);
		
		// Unbind the buffers
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); 
		glBindBuffer(GL_ARRAY_BUFFER, 0); 
	}
}

- (void)freeVertexBuffers;
{
	if (isRenderingCancelled)
		return;
	unsigned int bufferIndex;
	for (bufferIndex = 0; bufferIndex < m_numberOfVertexBuffers; bufferIndex++)
	{
		glDeleteBuffers(1, &m_indexBufferHandle[bufferIndex]);
		glDeleteBuffers(1, &m_vertexBufferHandle[bufferIndex]);
	}

	
	if (m_vertexBufferHandle != NULL)
	{
		free(m_vertexBufferHandle);
		m_vertexBufferHandle = NULL;
	}
	if (m_indexBufferHandle != NULL)
	{
		free(m_indexBufferHandle);
		m_indexBufferHandle = NULL;
	}
	if (m_numberOfIndicesForBuffers != NULL)
	{
		free(m_numberOfIndicesForBuffers);
		m_numberOfIndicesForBuffers = NULL;
	}
	
	totalNumberOfTriangles = 0;
	totalNumberOfVertices = 0;
}

#pragma mark -
#pragma mark Accessors

@synthesize centerOfMassInX, centerOfMassInY, centerOfMassInZ;
@synthesize filename, filenameWithoutExtension, title, keywords, journalAuthor, journalTitle, journalReference, sequence, compound, source, author;
@synthesize isBeingDisplayed, isDoneRendering, isRenderingCancelled;
@synthesize numberOfAtoms, numberOfStructures;
@synthesize previousTerminalAtomValue;
@synthesize currentVisualizationType;
@synthesize totalNumberOfVertices, totalNumberOfTriangles;
@synthesize numberOfStructureBeingDisplayed;


- (void)setIsBeingDisplayed:(BOOL)newValue;
{
	if (newValue == isBeingDisplayed)
		return;
	isBeingDisplayed = newValue;
	if (isBeingDisplayed)
	{
		isRenderingCancelled = NO;
		[self performSelectorInBackground:@selector(renderMolecule) withObject:nil];
	}
	else
		[self freeVertexBuffers];
}

- (void)setCurrentVisualizationType:(SLSVisualizationType)newVisualizationType;
{
	if (currentVisualizationType == newVisualizationType)
		return;
	currentVisualizationType = newVisualizationType;
	// Clear out the old render
	self.isBeingDisplayed = NO;
	// Start with a new render for the current visualization type
	self.isBeingDisplayed = YES;
}

@end
