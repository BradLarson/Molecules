//
//  SLSMoleculeLibraryTableCell.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 4/30/2011.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface SLSMoleculeLibraryTableCell : UITableViewCell 
{
    CAGradientLayer *highlightGradientLayer;
    BOOL isSelected;
}

@property(strong, nonatomic) CAGradientLayer *highlightGradientLayer;
@property(assign, nonatomic) BOOL isSelected;

@end
