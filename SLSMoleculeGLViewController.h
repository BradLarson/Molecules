//
//  SLSMoleculeGLViewController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 6/30/2008.
//
//  A barebones controller for managing the OpenGL view of the molecule.  It's pretty sparse, as some of the methods in the view really belong here.

#import <UIKit/UIKit.h>

@class SLSMolecule;

@interface SLSMoleculeGLViewController : UIViewController 
{
}

- (void)selectedMoleculeDidChange:(SLSMolecule *)newMolecule;

@end
