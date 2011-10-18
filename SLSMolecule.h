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

extern NSString *const kSLSMoleculeRenderingStartedNotification;
extern NSString *const kSLSMoleculeRenderingUpdateNotification;
extern NSString *const kSLSMoleculeRenderingEndedNotification;

@class SLSOpenGLESRenderer;

// TODO: Convert enum to elemental number
typedef enum { CARBON, HYDROGEN, OXYGEN, NITROGEN, SULFUR, PHOSPHOROUS, IRON, UNKNOWN, SILICON, FLUORINE, CHLORINE, BROMINE, IODINE, CALCIUM, ZINC, CADMIUM, SODIUM, MAGNESIUM, NUM_ATOMTYPES } SLSAtomType;
typedef enum { BALLANDSTICK, SPACEFILLING, CYLINDRICAL, } SLSVisualizationType;
typedef enum { UNKNOWNRESIDUE, DEOXYADENINE, DEOXYCYTOSINE, DEOXYGUANINE, DEOXYTHYMINE, ADENINE, CYTOSINE, GUANINE, URACIL, GLYCINE, ALANINE, VALINE, 
				LEUCINE, ISOLEUCINE, SERINE, CYSTEINE, THREONINE, METHIONINE, PROLINE, PHENYLALANINE, TYROSINE, TRYPTOPHAN, HISTIDINE,
				LYSINE, ARGININE, ASPARTICACID, GLUTAMICACID, ASPARAGINE, GLUTAMINE, WATER, NUM_RESIDUETYPES } SLSResidueType;
typedef enum { MOLECULESOURCE, MOLECULEAUTHOR, JOURNALAUTHOR, JOURNALTITLE, JOURNALREFERENCE, MOLECULESEQUENCE } SLSMetadataType;
typedef enum { SINGLEBOND, DOUBLEBOND, TRIPLEBOND } SLSBondType;

typedef struct { 
	GLfloat x; 
	GLfloat y; 
	GLfloat z; 
} SLS3DPoint;

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

	// A holder for rendering connecting bonds
	NSValue *previousTerminalAtomValue;
	BOOL reverseChainDirection;
		
	// Database values
	sqlite3 *database;
	BOOL isPopulatedFromDatabase;
	NSInteger databaseKey;	
    
    // Molecule properties for scaling and translation
	float centerOfMassInX, centerOfMassInY, centerOfMassInZ;
	float minimumXPosition, maximumXPosition, minimumYPosition, maximumYPosition, minimumZPosition, maximumZPosition;
	float scaleAdjustmentForX, scaleAdjustmentForY, scaleAdjustmentForZ;

    SLSOpenGLESRenderer *currentRenderer;
}

@property (readonly) float centerOfMassInX, centerOfMassInY, centerOfMassInZ;
@property (readonly) NSString *filename, *filenameWithoutExtension, *title, *keywords, *journalAuthor, *journalTitle, *journalReference, *sequence, *compound, *source, *author;
@property (readwrite, nonatomic) BOOL isBeingDisplayed, isRenderingCancelled;
@property (readonly) BOOL isDoneRendering;
@property (readonly) unsigned int numberOfAtoms, numberOfStructures;
@property (readwrite, strong) NSValue *previousTerminalAtomValue;
@property (readwrite, nonatomic) SLSVisualizationType currentVisualizationType;
@property (readwrite) unsigned int numberOfStructureBeingDisplayed;

- (id)initWithFilename:(NSString *)newFilename database:(sqlite3 *)newDatabase title:(NSString *)newTitle;
- (id)initWithSQLStatement:(sqlite3_stmt *)moleculeRetrievalStatement database:(sqlite3 *)newDatabase;
- (void)deleteMolecule;

+ (BOOL)isFiletypeSupportedForFile:(NSString *)filePath;
+ (void)setBondColor:(GLubyte *)bondColor forResidueType:(SLSResidueType)residueType;

// Database methods
+ (BOOL)beginTransactionWithDatabase:(sqlite3 *)database;
+ (BOOL)endTransactionWithDatabase:(sqlite3 *)database;
+ (void)finalizeStatements;
- (void)writeMoleculeDataToDatabase;
- (void)addMetadataToDatabase:(NSString *)metadata type:(SLSMetadataType)metadataType;
- (NSInteger)addAtomToDatabase:(SLSAtomType)atomType atPoint:(SLS3DPoint)newPoint structureNumber:(NSInteger)structureNumber residueKey:(SLSResidueType)residueKey;
- (void)addBondToDatabaseWithStartPoint:(NSValue *)startValue endPoint:(NSValue *)endValue bondType:(SLSBondType)bondType structureNumber:(NSInteger)structureNumber residueKey:(NSInteger)residueKey;
- (void)readMetadataFromDatabaseIfNecessary;
- (void)deleteMoleculeDataFromDatabase;
- (NSInteger)countAtomsForFirstStructure;
- (NSInteger)countBondsForFirstStructure;

// Status notification methods
- (void)showStatusIndicator;
- (void)updateStatusIndicator;
- (void)hideStatusIndicator;

// Rendering
- (void)switchToDefaultVisualizationMode;
- (BOOL)renderMolecule:(SLSOpenGLESRenderer *)openGLESRenderer;
- (void)readAndRenderAtoms:(SLSOpenGLESRenderer *)openGLESRenderer;
- (void)readAndRenderBonds:(SLSOpenGLESRenderer *)openGLESRenderer;

@end
