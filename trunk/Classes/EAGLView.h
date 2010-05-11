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
//  EAGLView.h
//  iPhone Quake
//
//  Kevin Arunski, October 2008 - Graphics, Network, and Sound support
//  Todd Moore, October 2008 - Multitouch Controls, Accelerometer, and Overlay Support
//  More information can be found at www.tmsoft.com
//


#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

/*
This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass.
The view content is basically an EAGL surface you render your OpenGL scene into.
Note that setting the view non-opaque will only work if the EAGL surface has an alpha channel.
*/
@interface EAGLView : UIView <UITextFieldDelegate> // for keyboard
{
    
@private
    /* The pixel dimensions of the backbuffer */
    GLint backingWidth;
    GLint backingHeight;
    
    EAGLContext *context;
    
    /* OpenGL names for the renderbuffer and framebuffers used to render to this view */
    GLuint viewRenderbuffer, viewFramebuffer;
    
    /* OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist) */
    GLuint depthRenderbuffer;
    
    NSTimer *animationTimer;
    NSTimeInterval animationInterval;
	
	// update gl surface
	bool drawGL;
	
	// use accelorometer
	bool useAccelerometer;
	
	/* time of last frame */
	double oldtime;
	
	// touch logic for freelook and button presses
	CGRect touchRect[7][2]; // screen location of touch areas
	id touchId[7];          // assigned button ids on touch begin
	CGPoint touchLook;      // current position of free look (center area)
	
	// Menu overlay and keyboard input view
	UIView *menuView;
	UITextField *textView;
	
	// Last destination of keyboard input
	unsigned int lastKeyDest;
	// Last keyboard key pressed
	int key;
}

@property NSTimeInterval animationInterval;

- (void)startAnimation;
- (void)stopAnimation;
- (void)drawView;

// get a mask representing all regions that are current touched
- (unsigned int) getTouchMask;
// get current free look position
- (CGPoint) getTouchLook;
// get keyboard pressed key (0 if none)
- (int) getKey;
- (bool) getUseAccelerometer;

+ (EAGLView *)instance;

@end
