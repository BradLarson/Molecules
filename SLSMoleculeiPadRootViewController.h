//
//  SLSMoleculeiPadRootViewController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 2/20/2010.
//

#import "SLSMoleculeRootViewController.h"

@class UIPopoverController;

@interface SLSMoleculeiPadRootViewController : SLSMoleculeRootViewController <UISplitViewControllerDelegate, UIPopoverControllerDelegate>
{
	UIImage *unselectedRotationImage, *selectedRotationImage;
	UIBarButtonItem *rotationBarButton, *spacerItem, *visualizationBarButton, *colorKeyBarButton;
	UIToolbar *mainToolbar;
	UIPopoverController *downloadOptionsPopover, *moleculeTablePopover, *colorKeyPopover;
	
	UIScreen *externalScreen;
	
	UIWindow *externalWindow;
}

// Bar response methods
//- (void)showMolecules:(id)sender;
- (void)showVisualizationModes:(id)sender;
- (void)showDownloadOptions:(id)sender;
- (void)showColorKey:(id)sender;

// External monitor support
- (void)handleConnectionOfMonitor:(NSNotification *)note;
- (void)handleDisconnectionOfMonitor:(NSNotification *)note;
- (void)displayOnExternalOrLocalScreen:(id)sender;

@end
