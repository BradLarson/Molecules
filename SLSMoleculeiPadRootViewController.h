//
//  SLSMoleculeiPadRootViewController.h
//  Molecules
//
//  Created by Brad Larson on 2/20/2010.
//  Copyright 2010 Sunset Lake Software LLC. All rights reserved.
//

#import "SLSMoleculeRootViewController.h"

@class UIPopoverController;

@interface SLSMoleculeiPadRootViewController : SLSMoleculeRootViewController <UISplitViewControllerDelegate, UIPopoverControllerDelegate>
{
	UIImage *unselectedRotationImage, *selectedRotationImage;
	UIBarButtonItem *rotationBarButton, *spacerItem, *visualizationBarButton;
	UIToolbar *mainToolbar;
	UIPopoverController *downloadOptionsPopover;
}

// Bar response methods
//- (void)showMolecules:(id)sender;
- (void)showVisualizationModes:(id)sender;
- (void)showDownloadOptions:(id)sender;

@end
