//
//  SLSMolecule.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/26/2008.
//
//  This is the model class for the molecule object.  It parses a PDB file, generates a vertex buffer object, and renders that object to the screen

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <sqlite3.h>


// TODO: Convert enum to elemental number
typedef enum { CARBON, HYDROGEN, OXYGEN, NITROGEN, SULFUR, PHOSPHOROUS, IRON, UNKNOWN, SILICON } SLSAtomType;
typedef enum { BALLANDSTICK, SPACEFILLING, CYLINDRICAL, } SLSVisualizationType;
typedef enum { UNKNOWNRESIDUE, DEOXYADENINE, DEOXYCYTOSINE, DEOXYGUANINE, DEOXYTHYMINE, ADENINE, CYTOSINE, GUANINE, URACIL, GLYCINE, ALANINE, VALINE, 
				LEUCINE, ISOLEUCINE, SERINE, CYSTEINE, THREONINE, METHIONINE, PROLINE, PHENYLALANINE, TYROSINE, TRYPTOPHAN, HISTIDINE,
				LYSINE, ARGININE, ASPARTICACID, GLUTAMICACID, ASPARAGINE, GLUTAMINE, WATER } SLSResidueType;
typedef enum { MOLECULESOURCE, MOLECULEAUTHOR, JOURNALAUTHOR, JOURNALTITLE, JOURNALREFERENCE, MOLECULESEQUENCE } SLSMetadataType;
typedef enum { SINGLEBOND, DOUBLEBOND, TRIPLEBOND } SLSBondType;

typedef struct { 
	GLfloat x; 
	GLfloat y; 
	GLfloat z; 
} SLS3DPoint;

// OpenGL helper functions
void normalize(GLfloat *v);


@interface SLSMolecule : NSObject 
{
	// Metadata from the Protein Data Bank
	unsigned int numberOfAtoms, numberOfBonds, numberOfStructures;
	NSString *filename, *filenameWithoutExtension, *title, *keywords, *journalAuthor, *journalTitle, *journalReference, *sequence, *compound, *source, *author;

	// Status of the molecule
	BOOL isBeingDisplayed, isDoneRendering, isRenderingCancelled;
	SLSVisualizationType currentVisualizationType;
	unsigned int numberOfStructureBeingDisplayed;
	unsigned int totalNumberOfFeaturesToRender, currentFeatureBeingRendered;
	BOOL stillCountingAtomsInFirstStructure;

	// OpenGL vertex buffer objects
	unsigned int *m_numberOfIndicesForBuffers;
	GLuint *m_vertexBufferHandle, *m_indexBufferHandle;
	NSMutableArray *m_vertexArrays, *m_indexArrays;
	unsigned int m_numberOfVertexBuffers;
	NSMutableData *m_vertexArray, *m_indexArray;
	unsigned int m_numVertices, m_numIndices;
	
	// OpenGL performance tuning statistics
	NSInteger totalNumberOfVertices, totalNumberOfTriangles;

	// A holder for rendering connecting bonds
	NSValue *previousTerminalAtomValue;
	BOOL reverseChainDirection;
	
	// Molecule properties for scaling and translation
	float centerOfMassInX, centerOfMassInY, centerOfMassInZ;
	float minimumXPosition, maximumXPosition, minimumYPosition, maximumYPosition, minimumZPosition, maximumZPosition;
	float scaleAdjustmentForX, scaleAdjustmentForY, scaleAdjustmentForZ;
	
	// Database values
	sqlite3 *database;
	BOOL isPopulatedFromDatabase;
	NSInteger databaseKey;
	
	// Processing queue
	NSOperationQueue *renderingQueue;
}

@property (readonly) float centerOfMassInX, centerOfMassInY, centerOfMassInZ;
@property (readonly) NSString *filename, *filenameWithoutExtension, *title, *keywords, *journalAuthor, *journalTitle, *journalReference, *sequence, *compound, *source, *author;
@property (readwrite, nonatomic) BOOL isBeingDisplayed, isRenderingCancelled;
@property (readonly) BOOL isDoneRendering;
@property (readonly) unsigned int numberOfAtoms, numberOfStructures;
@property (readwrite, retain) NSValue *previousTerminalAtomValue;
@property (readwrite, nonatomic) SLSVisualizationType currentVisualizationType;
@property (readonly) NSInteger totalNumberOfVertices, totalNumberOfTriangles;
@property (readwrite) unsigned int numberOfStructureBeingDisplayed;
@property (readwrite, retain, nonatomic) NSOperationQueue *renderingQueue;

- (id)initWithFilename:(NSString *)newFilename database:(sqlite3 *)newDatabase;
- (id)initWithSQLStatement:(sqlite3_stmt *)moleculeRetrievalStatement database:(sqlite3 *)newDatabase;
- (void)deleteMolecule;

+ (BOOL)isFiletypeSupportedForFile:(NSString *)filePath;

// Molecule 3-D geometry generation
+ (void)setBondColor:(GLubyte *)bondColor forResidueType:(SLSResidueType)residueType;
- (void)addNormal:(GLfloat *)newNormal;
- (void)addVertex:(GLfloat *)newVertex;
- (void)addIndex:(GLushort *)newIndex;
- (void)addColor:(GLubyte *)newColor;
- (void)addAtomToVertexBuffers:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint;
- (void)addBondToVertexBuffersWithStartPoint:(SLS3DPoint)startPoint endPoint:(SLS3DPoint)endPoint bondColor:(GLubyte *)bondColor bondType:(SLSBondType)bondType;

// Database methods
+ (BOOL)beginTransactionWithDatabase:(sqlite3 *)database;
+ (BOOL)endTransactionWithDatabase:(sqlite3 *)database;
+ (void)finalizeStatements;
- (void)writeMoleculeDataToDatabase;
- (void)addMetadataToDatabase:(NSString *)metadata type:(SLSMetadataType)metadataType;
- (NSInteger)addAtomToDatabase:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint structureNumber:(NSInteger)structureNumber residueKey:(SLSResidueType)residueKey;
- (void)addBondToDatabaseWithStartPoint:(NSValue *)startValue endPoint:(NSValue *)endValue bondType:(SLSBondType)bondType structureNumber:(NSInteger)structureNumber residueKey:(NSInteger)residueKey;
- (void)readMetadataFromDatabaseIfNecessary;
- (void)readAndRenderAtoms;
- (void)readAndRenderBonds;
- (void)deleteMoleculeDataFromDatabase;

// Status notification methods
- (void)showStatusIndicator;
- (void)updateStatusIndicator;
- (void)hideStatusIndicator;

// OpenGL drawing routines
- (void)addVertexBuffer;
- (BOOL)renderMolecule;
- (void)bindVertexBuffersForMolecule;
- (void)drawMolecule;
- (void)freeVertexBuffers;

@end
