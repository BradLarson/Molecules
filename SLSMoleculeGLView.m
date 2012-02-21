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

        
        [openGLESRenderer createFramebuffersForLayer:eaglLayer];
        [openGLESRenderer clearScreen];
	}
	return self;
}

-(void)snapUIImage
{
//    From http://stackoverflow.com/q/4787311/19679
    
    int s = 1;
    UIScreen* screen = [ UIScreen mainScreen ];
    if ( [ screen respondsToSelector:@selector(scale) ] )
        s = (int) [ screen scale ];
    
    const int w = self.frame.size.width;
    const int h = self.frame.size.height;
    const NSInteger myDataLength = w * h * 4 * s * s;
    // allocate array and read pixels into it.
    GLubyte *buffer = (GLubyte *) malloc(myDataLength);
    glReadPixels(0, 0, w*s, h*s, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
    // gl renders "upside down" so swap top to bottom into new array.
    // there's gotta be a better way, but this works.
    GLubyte *buffer2 = (GLubyte *) malloc(myDataLength);
    for(int y = 0; y < h*s; y++)
    {
        memcpy( buffer2 + (h*s - 1 - y) * w * 4 * s, buffer + (y * 4 * w * s), w * 4 * s );
    }
    free(buffer); // work with the flipped buffer, so get rid of the original one.
    
    // make data provider with data.
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer2, myDataLength, NULL);
    // prep the ingredients
    int bitsPerComponent = 8;
    int bitsPerPixel = 32;
    int bytesPerRow = 4 * w * s;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    // make the cgimage
    CGImageRef imageRef = CGImageCreate(w*s, h*s, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    // then make the uiimage from that
    UIImage *myImage = [ UIImage imageWithCGImage:imageRef scale:s orientation:UIImageOrientationUp ];
    UIImageWriteToSavedPhotosAlbum( myImage, nil, nil, nil );
    CGImageRelease( imageRef );
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpaceRef);
    free(buffer2);
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
