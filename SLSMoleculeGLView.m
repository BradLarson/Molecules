//
//  SLSMoleculeGLView.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 5/18/2008.
//
//  This view manages the OpenGL scene, with setup and rendering methods.  Multitouch events are also handled
//  here, although it might be best to refactor some of the code up to a controller.


#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import "SLSOpenGLES11Renderer.h"
#import "SLSOpenGLES20Renderer.h"

#import "SLSMoleculeGLView.h"
#import "SLSMolecule.h"

@implementation SLSMoleculeGLView

// Override the class method to return the OpenGL layer, as opposed to the normal CALayer
+ (Class) layerClass 
{
	return [CAEAGLLayer class];
}

#pragma mark -
#pragma mark Initialization and breakdown

- (id)initWithFrame:(CGRect)aRect
{
	if ((self = [super initWithFrame:aRect])) 
	{
		self.multipleTouchEnabled = YES;
		self.opaque = YES;
        
        previousSize = aRect.size;
		
		// Set scaling to account for Retina display	
		if ([self respondsToSelector:@selector(setContentScaleFactor:)])
		{
			self.contentScaleFactor = [[UIScreen mainScreen] scale];
		}
		
		// Do OpenGL Core Animation layer setup
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
		
		eaglLayer.opaque = YES;
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
//										[NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGB565, kEAGLDrawablePropertyColorFormat, nil];
		
		
        EAGLContext *aContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
//        aContext = nil;
        
        if (!aContext) 
        {
            aContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
            openGLESRenderer = [[SLSOpenGLES11Renderer alloc] initWithContext:aContext];
        }
        else
        {
            openGLESRenderer = [[SLSOpenGLES20Renderer alloc] initWithContext:aContext];
        }

        [aContext release];
        
        [openGLESRenderer createFramebuffersForLayer:eaglLayer];
        [openGLESRenderer clearScreen];
	}
	return self;
}


#pragma mark -
#pragma mark UIView methods

- (void)layoutSubviews 
{
    CGSize newSize = self.bounds.size;
    if (!CGSizeEqualToSize(newSize, previousSize))
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GLViewSizeDidChange" object:nil];
        previousSize = newSize;
    }
}

#pragma mark -
#pragma mark Accessors

@synthesize openGLESRenderer;

@end
