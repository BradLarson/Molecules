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

#import "SLSMoleculeGLView.h"
#import "SLSMolecule.h"

#define USE_DEPTH_BUFFER 1
//#define RUN_OPENGL_BENCHMARKS

// A class extension to declare private methods
@interface SLSMoleculeGLView ()

@property (nonatomic, retain) EAGLContext *context;

- (BOOL) createFramebuffer;
- (void) destroyFramebuffer;

@end


@implementation SLSMoleculeGLView

@synthesize context;

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
		
		// Do OpenGL Core Animation layer setup
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
		
		eaglLayer.opaque = YES;
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
		
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
		
		if (!context || ![EAGLContext setCurrentContext:context] || ![self createFramebuffer]) 
		{
			[self release];
			return nil;
		}
		
		[self clearScreen];		
	}
	return self;
}

- (void)dealloc 
{
//	// Read the current modelview matrix from OpenGL and save it in the user's preferences for recovery on next startup
//	// TODO: save index, vertex, and normal buffers for quick reload later
//	float currentModelViewMatrix[16];
//	glMatrixMode(GL_MODELVIEW);
//	glGetFloatv(GL_MODELVIEW_MATRIX, currentModelViewMatrix);	
//	NSData *matrixData = [NSData dataWithBytes:currentModelViewMatrix length:(16 * sizeof(float))];	
//	[[NSUserDefaults standardUserDefaults] setObject:matrixData forKey:@"matrixData"];	
//	
	if ([EAGLContext currentContext] == context) 
	{
		[EAGLContext setCurrentContext:nil];
	}
	
	[context release];	

	[super dealloc];
}

#pragma mark -
#pragma mark OpenGL drawing

- (void)configureLighting;
{
	const GLfloat			lightAmbient[] = {0.2, 0.2, 0.2, 1.0};
	const GLfloat			lightDiffuse[] = {1.0, 1.0, 1.0, 1.0};
	const GLfloat			matAmbient[] = {1.0, 1.0, 1.0, 1.0};
	const GLfloat			matDiffuse[] = {1.0, 1.0, 1.0, 1.0};	
	const GLfloat			lightPosition[] = {0.466, -0.466, 0, 0}; 
	const GLfloat			lightShininess = 20.0;	
	
	glEnable(GL_LIGHTING);
	glEnable(GL_LIGHT0);
	glEnable(GL_COLOR_MATERIAL);
	glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, matAmbient);
	glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, matDiffuse);
	glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, lightShininess);
	glLightfv(GL_LIGHT0, GL_AMBIENT, lightAmbient);
	glLightfv(GL_LIGHT0, GL_DIFFUSE, lightDiffuse);
	glLightfv(GL_LIGHT0, GL_POSITION, lightPosition); 		
	
#ifdef USE_DEPTH_BUFFER
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LEQUAL);
#else
	glDisable(GL_DEPTH_TEST);
#endif
	
	glShadeModel(GL_SMOOTH);
	glDisable(GL_NORMALIZE);		
	glEnable(GL_RESCALE_NORMAL);		
	
	glEnableClientState (GL_VERTEX_ARRAY);
	glEnableClientState (GL_NORMAL_ARRAY);
	glEnableClientState (GL_COLOR_ARRAY);
	
	glDisable(GL_ALPHA_TEST);
	glDisable(GL_FOG);
	glEnable(GL_CULL_FACE);
	glCullFace(GL_FRONT);
	
	//	glEnable(GL_LINE_SMOOTH);	
}

- (void)clearScreen;
{
	[EAGLContext setCurrentContext:context];
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];

}

- (void)startDrawingFrame;
{
	[EAGLContext setCurrentContext:context];
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glViewport(0, 0, backingWidth, backingHeight);
	glScissor(0, 0, backingWidth, backingHeight);	
}

- (void)configureProjection;
{
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	
//	glOrthof(-32768.0f, 32768.0f, -1.5f * 32768.0f, 1.5f * 32768.0f, -10.0f * 32768.0f, 4.0f * 32768.0f);
	glOrthof(-32768.0f, 32768.0f, -((float)backingHeight / (float)backingWidth) * 32768.0f, ((float)backingHeight / (float)backingWidth) * 32768.0f, -10.0f * 32768.0f, 4.0f * 32768.0f);
}

- (void)presentRenderBuffer;
{
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

#pragma mark -
#pragma mark OpenGL framebuffer helper methods

- (BOOL)createFramebuffer 
{	
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);

	[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
#ifdef USE_DEPTH_BUFFER
		glGenRenderbuffersOES(1, &depthRenderbuffer);
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
		glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
		glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
#endif
	
	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) 
	{
		return NO;
	}
	
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);

	return YES;
}

- (void)destroyFramebuffer 
{
	
	glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
	
	if(depthRenderbuffer) {
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
}

#pragma mark -
#pragma mark UIView methods

- (void)layoutSubviews 
{
	[EAGLContext setCurrentContext:context];
	[self destroyFramebuffer];
	[self createFramebuffer];
	[self configureProjection];
//	[self drawView];
}

@end
