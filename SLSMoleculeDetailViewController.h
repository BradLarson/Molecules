//
//  SLSMoleculeDetailViewController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 7/5/2008.
//
//  This controller manages the detail view of the molecule's properties, such as author, publication, etc.

#import <UIKit/UIKit.h>

@class SLSMolecule;

@interface SLSMoleculeDetailViewController : UITableViewController 
{
	SLSMolecule *molecule;
	
	UILabel *nameLabel;	
}

@property (nonatomic, strong) SLSMolecule *molecule;
- (id)initWithStyle:(UITableViewStyle)style andMolecule:(SLSMolecule *)newMolecule;

- (UILabel *)createLabelForIndexPath:(NSIndexPath *)indexPath;
- (NSString *)textForIndexPath:(NSIndexPath *)indexPath;

@end