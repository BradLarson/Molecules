//
//  SLSMoleculeCustomDownloadViewController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 11/10/2008.

#import <UIKit/UIKit.h>

@protocol MoleculeCustomDownloadDelegate;

@interface SLSMoleculeCustomDownloadViewController : UIViewController <UITextFieldDelegate>
{
	id <MoleculeCustomDownloadDelegate> delegate;
	UITextField *urlInput;
//	UIActivityIndicatorView *downloadActivityIndicator;
}

@property(readwrite, assign) id <MoleculeCustomDownloadDelegate> delegate;

@end


@protocol MoleculeCustomDownloadDelegate <NSObject>
- (void)customURLSelectedForMoleculeDownload:(NSURL *)customURLForMoleculeDownload;
@end
