/*
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
 
 See the GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 */

//
//  EAGLView.m
//  iPhone Quake
//
//  Kevin Arunski, October 2008 - Graphics, Network, and Sound support
//  Todd Moore, October 2008 - Multitouch Controls, Accelerometer, and Overlay Support
//  More information can be found at www.tmsoft.com
//

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#include <sys/time.h>
#import "EAGLView.h"

#include "quakedef.h"

// Width and Height are in landscape mode

// Because I'm lazy I'm assuming every device ever made will have a 480 x 320 screen.
// -KJA
#define WIDTH 480
#define HEIGHT 320
#define USE_DEPTH_BUFFER 1
#define degreesToRadian(x) (M_PI * x / 180.0)

int		texture_mode = GL_LINEAR;
int texture_extension_number = 1;
//int scr_width, scr_height = 0;
const GLubyte * gl_renderer;
const GLubyte * gl_extensions;
const GLubyte * gl_vendor;
const GLubyte * gl_version;
unsigned char d_15to8table[65536];
static qboolean is8bit = false;
qboolean isPermedia = false;
static float vid_gamma = 1.0;
unsigned	d_8to24table[256];
GLushort d_8to5_6_5table[256];
GLushort d_8to5_5_5_1table[256];
float		gldepthmin, gldepthmax;
qboolean gl_mtexable = false;
static EAGLView * myInstance;

cvar_t	gl_ztrick = {"gl_ztrick","1"};

static void Check_Gamma (unsigned char *pal)
{
	float	f, inf;
	unsigned char	palette[768];
	int		i;
	
	vid_gamma = 0.7; // default to 0.7 on non-3dfx hardware
	
	for (i=0 ; i<768 ; i++)
	{
		f = pow ( (pal[i]+1)/256.0 , vid_gamma );
		inf = f*255 + 0.5;
		if (inf < 0)
			inf = 0;
		if (inf > 255)
			inf = 255;
		palette[i] = inf;
	}
	
	memcpy (pal, palette, sizeof(palette));
}

void CheckMultiTextureExtensions(void) 
{
	gl_mtexable = true;
	Con_Printf("Using Open GL ES multitexturing.\n");
}

void GL_Init (void)
{
	gl_vendor = glGetString (GL_VENDOR);
	Con_Printf ("GL_VENDOR: %s\n", gl_vendor);
	gl_renderer = glGetString (GL_RENDERER);
	Con_Printf ("GL_RENDERER: %s\n", gl_renderer);
	
	gl_version = glGetString (GL_VERSION);
	Con_Printf ("GL_VERSION: %s\n", gl_version);
	gl_extensions = glGetString (GL_EXTENSIONS);
	Con_Printf ("GL_EXTENSIONS: %s\n", gl_extensions);
	
	//	Con_Printf ("%s %s\n", gl_renderer, gl_version);
	
	CheckMultiTextureExtensions ();
	
	glClearColor (0,0,0,1);
	glCullFace(GL_FRONT);
	glEnable(GL_TEXTURE_2D);
	
	glEnable(GL_ALPHA_TEST);
	glAlphaFunc(GL_GREATER, 0.666);
	
	// only filled polygons are supported in ES
	//glPolygonMode (GL_FRONT_AND_BACK, GL_FILL);
	glShadeModel (GL_SMOOTH);
	
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	
	glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	//	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
	
	
}

void VID_Init8bitPalette(void) 
{
	// no 8-bit shared palette.
	is8bit = false;
}

void VID_Init(unsigned char * palette)
{
	// tm: configure the width and height of screen for landscape
	vid.width = WIDTH; // required
	vid.height = HEIGHT; // required
	
	vid.aspect = ((float)vid.height / (float)vid.width); // tm: this seems to have no effect

	char	gldir[MAX_OSPATH];
	
	// tm: maxwarp seems to have no effect
	vid.maxwarpwidth = WIDTH;
	vid.maxwarpheight = HEIGHT;
	
	vid.colormap = host_colormap;
	vid.fullbright = 256 - LittleLong (*((int *)vid.colormap + 2048));
	vid.numpages = 2;
	
	GL_Init();
	
	sprintf (gldir, "%s/glquake", com_gamedir);
	Sys_mkdir (gldir);
	
	Check_Gamma(palette);
	VID_SetPalette(palette);
	
	// Check for 3DFX Extensions and initialize them.
	VID_Init8bitPalette();
	
	Con_SafePrintf ("Video mode %dx%d initialized.\n", vid.width, vid.height);
	
	vid.recalc_refdef = 1;				// force a surface cache flush
}

void VID_ShiftPalette(unsigned char *p)
{
}

void VID_SetPalette (unsigned char *palette)
{
	byte	*pal;
	unsigned r,g,b;
	unsigned v;
	int     r1,g1,b1;
	//int		j,k,l,m;
	int k;
	unsigned short i;
	unsigned	*table;
	//FILE *f;
	//char s[255];
	int dist, bestdist;
	//static qboolean palflag = false;
	
	//
	// 8 to 24 table: 8 8 8 encoding
	// 8 to 16 table: 5 6 5 encoding
	// 8 to 16 table w/ alpha: 5_5_5_1 encoding
	//
	pal = palette;
	table = d_8to24table;
	GLushort * table565 = d_8to5_6_5table;
	GLushort * table5551 = d_8to5_5_5_1table;
	for (i=0 ; i<256 ; i++)
	{
		GLushort shortColor;
		
		r = pal[0];
		g = pal[1];
		b = pal[2];
		pal += 3;
		
		v = (255<<24) + (r<<0) + (g<<8) + (b<<16);
		shortColor = ((r >> 3) << 11) + ((g >> 2) << 5) + (b >> 3);
		*table565++ = shortColor;
		shortColor = ((r >> 3) << 11) + ((g >> 3) << 6) + ((b >> 3) << 1) + 1;
		*table5551++ = shortColor;
		*table++ = v;
	}
	d_8to24table[255] &= 0xffffff;	// 255 is transparent
	d_8to5_5_5_1table[255] &= 0xfffe;
	
	// JACK: 3D distance calcs - k is last closest, l is the distance.
	for (i=0; i < (1<<15); i++) {
		/* Maps
		 000000000000000
		 000000000011111 = Red  = 0x1F
		 000001111100000 = Blue = 0x03E0
		 111110000000000 = Grn  = 0x7C00
		 */
		r = ((i & 0x1F) << 3)+4;
		g = ((i & 0x03E0) >> 2)+4;
		b = ((i & 0x7C00) >> 7)+4;
		pal = (unsigned char *)d_8to24table;
		for (v=0,k=0,bestdist=10000*10000; v<256; v++,pal+=4) {
			r1 = (int)r - (int)pal[0];
			g1 = (int)g - (int)pal[1];
			b1 = (int)b - (int)pal[2];
			dist = (r1*r1)+(g1*g1)+(b1*b1);
			if (dist < bestdist) {
				k=v;
				bestdist = dist;
			}
		}
		d_15to8table[i]=k;
	}
}

void VID_Shutdown(void)
{
}

qboolean VID_Is8bit(void)
{
	return is8bit;
}

void GL_EndRendering (void)
{
}

void GL_BeginRendering (int *x, int *y, int *width, int *height)
{
	//I think the actual draw setup happens in [EAGLView drawView]	
	*x = *y = 0;
	
	// tm: had to override the width and height for landscape
	*width = WIDTH;//scr_width;
	*height = HEIGHT;//scr_height;
	
	//    if (!wglMakeCurrent( maindc, baseRC ))
	//		Sys_Error ("wglMakeCurrent failed");
	
	//	glViewport (*x, *y, *width, *height);
}

double Sys_FloatTime (void)
{
    struct timeval tp;
    struct timezone tzp; 
    static int      secbase; 
    
    gettimeofday(&tp, &tzp);  
	
    if (!secbase)
    {
        secbase = tp.tv_sec;
        return tp.tv_usec/1000000.0;
    }
	
    return (tp.tv_sec - secbase) + tp.tv_usec/1000000.0;
}


// A class extension to declare private methods
@interface EAGLView ()

@property (nonatomic, retain) EAGLContext *context;
@property (nonatomic, assign) NSTimer *animationTimer;

- (BOOL) createFramebuffer;
- (void) destroyFramebuffer;
- (void) syncTouches:(NSSet *)allTouches;

@end


@implementation EAGLView

@synthesize context;
@synthesize animationTimer;
@synthesize animationInterval;

// You must implement this method
+ (Class)layerClass {
    return [CAEAGLLayer class];
}


//The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder 
{
    
    if ((self = [super initWithCoder:coder])) 
	{
		drawGL = true;
		
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;

        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking,
										//kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
										kEAGLColorFormatRGB565, kEAGLDrawablePropertyColorFormat,
										nil];
        
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        
        if (!context || ![EAGLContext setCurrentContext:context]) 
		{
            [self release];
            return nil;
        }
        
		animationInterval = 1.0 / 60.0;
		oldtime = Sys_FloatTime () - 0.1;
			
		// init touch regions to be the following
		// +------+------+------+
		// |   1  |  2   |  3   |
		// +------+------+------+
		// |         4          |
		// +------+------+------+
		// |   5  |  6   |  7   |
		// +------+------+------+
		
		// reset touch data
		key = 0;
		for (int i = 0; i < 7; ++i) 
		{
			touchId[i] = 0;
			touchRect[i][0] = CGRectMake(0,0,0,0);
			touchRect[i][1] = CGRectMake(0,0,0,0);
		}
		
		// setup game touch areas
		int w = eaglLayer.frame.size.width;
		int h = eaglLayer.frame.size.height;
		int size = 60;		
		touchRect[0][0] = CGRectMake(size,0,w-size*2,h); // middle area (first rect)
		for (int i = 0; i < 3; ++i)
		{
			// layout is really in portrait mode so have to rotate for that
			touchRect[i+1][0] = CGRectMake(w - size, i * (h / 3), size, h/3);
			touchRect[i+4][0] = CGRectMake(0, i * (h / 3), size, h/3);
		}
		
		// create a rotated view
		menuView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, h, w)];
		menuView.transform = CGAffineTransformConcat(menuView.transform, CGAffineTransformMakeRotation(degreesToRadian(90)));
		menuView.center = self.center;
		
		// create menu overlay
		UIImageView *imageView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"menu.png"]];
		imageView.userInteractionEnabled = TRUE;
		[menuView addSubview: imageView];
		[imageView release];
		
		// create text view off screen to use for keyboard pop up
		textView = [[UITextField alloc] initWithFrame: CGRectMake(0, -50, h, 25)];
		textView.backgroundColor = [UIColor clearColor];
		textView.textColor = [UIColor whiteColor];
		textView.hidden = TRUE;
		textView.text = @" "; // space is default so we can test for backspace
		textView.textAlignment = UITextAlignmentCenter;
		textView.delegate = self;
		textView.autocapitalizationType =  UITextAutocapitalizationTypeNone;
		// wire up notification from keyboard view
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:UITextFieldTextDidChangeNotification object: nil];
		
		[imageView addSubview: textView];
		
		lastKeyDest = key_dest;
		
		// create menu touch areas
		touchRect[0][1] = CGRectMake(230, 395, 75, 75); // Abc Keyboard
		touchRect[1][1] = CGRectMake(230,  12, 75, 75); // Esc
		touchRect[2][1] = CGRectMake( 55, 125, 75, 75); // Left
		touchRect[3][1] = CGRectMake( 55, 275, 75, 75); // Right
		touchRect[4][1] = CGRectMake( 55, 395, 75, 75); // Enter
		touchRect[5][1] = CGRectMake(105, 202, 75, 75); // Up
		touchRect[6][1] = CGRectMake( 15, 202, 75, 75); // Down

		useAccelerometer = true;
		
		// enable multi-touch
		self.multipleTouchEnabled = TRUE;
		myInstance = self;

    }
    return self;
}


- (void)drawView 
{
	if (drawGL)
	{
		[EAGLContext setCurrentContext:context];
		
		glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
		glViewport(0, 0, WIDTH, HEIGHT);
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
		
		double newtime = Sys_FloatTime ();
		double time = newtime - oldtime;
		if (time > sys_ticrate.value*2)
		{
			oldtime = newtime;
		}
		else
		{
			oldtime += time;
		}
		
		Host_Frame (time);
		
		[context presentRenderbuffer:GL_RENDERBUFFER_OES];
	}
	
	// check if view has changed
	if (lastKeyDest != key_dest)
	{
		if (key_dest != key_game && self.subviews.count == 0)
		{
			// show menu
			[self addSubview: menuView];
		}
		else if (key_dest == key_game && self.subviews.count > 0)
		{
			// remove menu
			[menuView removeFromSuperview];
		}
	}
	lastKeyDest = key_dest;
}


// get a mask representing all regions that are current touched
- (unsigned int) getTouchMask
{
	unsigned int mask = 0;
	if (touchId[0]) mask |= 1;
	if (touchId[1]) mask |= 2;
	if (touchId[2]) mask |= 4;
	if (touchId[3]) mask |= 8;
	if (touchId[4]) mask |= 16;
	if (touchId[5]) mask |= 32;
	if (touchId[6]) mask |= 64;
	return mask;
}

// get current free look position
- (CGPoint) getTouchLook
{
	return touchLook;
}

- (void)syncTouches:(NSSet *)allTouches
{
	int touchGroup = (key_dest == key_game) ? 0 : 1;
	
	NSEnumerator * touchEnumerator = [allTouches objectEnumerator];
	UITouch * touchEvent;
	// check each touch begin event
	while ((touchEvent = [touchEnumerator nextObject]))
	{
		CGPoint pt = [touchEvent locationInView:self];
		// check if any of the touch began events hit our layout regions
		for (int i = 0; i < 7; ++i)
		{
			// check if we found a previously registered id
			if (touchId[i] == touchEvent)
			{
				// check if we should end this event
				if (touchEvent.phase == UITouchPhaseEnded || touchEvent.phase == UITouchPhaseCancelled)
				{
					// terminate the touch event for this region
					touchId[i] = 0;
					//NSLog(@"Touch region %u ended", i+1);
				}
				else if (touchEvent.phase == UITouchPhaseMoved && touchGroup == 0 && i == 0) // free look
				{
					// we track the middle region so update position
					touchLook = pt;
					//NSLog(@"Touch region %u moved and tracking (%u,%u)", i+1, (int) pt.x, (int) pt.y);
				}
			}
			else if (touchEvent.phase == UITouchPhaseBegan && CGRectContainsPoint(touchRect[i][touchGroup], pt))
			{
				// this touch falls into region so store the touch id
				touchId[i] = touchEvent;
				// check for region #0 which is our special region for freelook and keyboard
				if (i == 0)
				{
					// check for free look (game) or keyboard mode
					if (touchGroup == 0) 
					{
						touchLook = pt;
						if (touchEvent.tapCount > 1)
						{
							useAccelerometer = !useAccelerometer;
						}
					}
					else
					{
						if (textView.hidden)
						{
							// bring up keyboard for name
							textView.hidden = NO;
							[textView becomeFirstResponder];
						}
						else
						{
							// bring up keyboard for name
							[textView resignFirstResponder];
							textView.hidden = YES;
						}
					}
				}
				//NSLog(@"Touch region %u began", i+1);
			}
	
		} // for each region
	
	} // for each touch
	
}

- (bool) getUseAccelerometer
{
	return useAccelerometer;
}

// get last key pressed
- (int) getKey
{
	int k = key;
	key = 0;
	return k;
}

// everytime the text view changes we get a callback.  the default text is a single space
// so we can check for backspace (size 0) or if a new char was added (size 2)
- (void) textDidChange: (id) object
{
	if (textView.text.length == 0)
	{
		key = K_BACKSPACE;
		textView.text = @" ";
	}
	else if (textView.text.length == 2)
	{
		// could have a unicode issue here on international keyboard (trim to 256)
		key = ([textView.text characterAtIndex: 1] & 0xff);
		textView.text = @" ";
	}
}

// keyboard input
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	key = K_ENTER;
	return FALSE;
	
	// When the user presses return, take focus away from the text field so that the keyboard is dismissed.
	[textView resignFirstResponder];
	
	if (textView.text.length == 0)
	{
		key = '\b';
	}
	else if (textView.text.length == 2)
	{
		key = [textView.text characterAtIndex: 1];
	}
	
	// take the string up
	textView.text = @" ";

	// disable direct clicking
	textView.hidden = YES;

	return NO;
}

// handle touch message
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self syncTouches:[event allTouches]];
}

// handle touch message
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self syncTouches:[event allTouches]];
}

// handle touch message
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self syncTouches:[event allTouches]];
}

// handle touch message
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self syncTouches:[event allTouches]];
}

- (void)layoutSubviews 
{
    [EAGLContext setCurrentContext:context];
    [self destroyFramebuffer];
    [self createFramebuffer];
    [self drawView];
}


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
    
    if (USE_DEPTH_BUFFER) 
	{
        glGenRenderbuffersOES(1, &depthRenderbuffer);
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
        glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
    }
    
    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) 
	{
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
        return NO;
    }
    
    return YES;
}


- (void)destroyFramebuffer 
{
    
    glDeleteFramebuffersOES(1, &viewFramebuffer);
    viewFramebuffer = 0;
    glDeleteRenderbuffersOES(1, &viewRenderbuffer);
    viewRenderbuffer = 0;
    
    if(depthRenderbuffer) 
	{
        glDeleteRenderbuffersOES(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }
}


- (void)startAnimation 
{

    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:animationInterval target:self selector:@selector(drawView) userInfo:nil repeats:YES];
}


- (void)stopAnimation 
{
    self.animationTimer = nil;
}


- (void)setAnimationTimer:(NSTimer *)newTimer 
{
    [animationTimer invalidate];
    animationTimer = newTimer;
}


- (void)setAnimationInterval:(NSTimeInterval)interval 
{
    
    animationInterval = interval;
    if (animationTimer) 
	{
        [self stopAnimation];
        [self startAnimation];
    }
}


- (void)dealloc 
{    
    [self stopAnimation];
    
    if ([EAGLContext currentContext] == context) 
	{
        [EAGLContext setCurrentContext:nil];
    }
    
    [context release];
	
	[textView release];
	[menuView release];
	
    [super dealloc];
}

+ (EAGLView *)instance 
{
	return myInstance;
}

@end
