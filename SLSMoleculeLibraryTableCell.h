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
    CAGradientLayer *__unsafe_unretained highlightGradientLayer;
    BOOL isSelected;
}

@property(unsafe_unretained, nonatomic) CAGradientLayer *highlightGradientLayer;
@property(assign, nonatomic) BOOL isSelected;

@end
