//
//  SLSmoleculeGLView.h
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 5/18/2008.
//
//  This view manages the OpenGL scene, with setup and rendering methods.  Multitouch events are also handled
//  here, although it might be best to refactor some of the code up to a controller.

#import <UIKit/UIKit.h>

@class SLSOpenGLESRenderer;

@interface SLSMoleculeGLView : UIView
{
    SLSOpenGLESRenderer *openGLESRenderer;
    CGSize previousSize;
}

@property(readonly) SLSOpenGLESRenderer *openGLESRenderer;

-(void)snapUIImage;

@end
