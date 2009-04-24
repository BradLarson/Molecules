//
//  SLSMoleculeDataSourceViewController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 11/9/2008.
//
//  This handles the table view listing the different data sources Molecule supports

#import <UIKit/UIKit.h>
#import "SLSMoleculeDownloadViewController.h"
#import "SLSMoleculeCustomDownloadViewController.h"

@interface SLSMoleculeDataSourceViewController : UITableViewController <MoleculeDownloadDelegate, MoleculeCustomDownloadDelegate>
{
	id<MoleculeDownloadDelegate, MoleculeCustomDownloadDelegate> delegate;
}

@property (readwrite, assign) id<MoleculeDownloadDelegate, MoleculeCustomDownloadDelegate> delegate;

@end
