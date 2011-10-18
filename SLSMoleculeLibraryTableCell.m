//
//  SLSMoleculeLibraryTableCell.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 4/30/2011.
//

#import "SLSMoleculeLibraryTableCell.h"

@implementation SLSMoleculeLibraryTableCell

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
	{
        isSelected = NO;
        // Initialization code
    }
    return self;
}



//- (void)setSelected:(BOOL)selected animated:(BOOL)animated 
//{
//
//    [super setSelected:selected animated:animated];
//
//    // Configure the view for the selected state
//}

#pragma mark -
#pragma mark Accessors

@synthesize highlightGradientLayer;
@synthesize isSelected;

@end
