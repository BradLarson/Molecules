//
//  SLSAtomColorKeyController.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "SLSMolecule.h"

@interface SLSAtomColorKeyController : UITableViewController

+ (CAGradientLayer *)atomColorOverlayGradientForSize:(CGSize)gradientSize;
+ (void)adjustGradient:(CAGradientLayer *)gradientLayer toMatchAtomType:(SLSAtomType)atomType;

@end
