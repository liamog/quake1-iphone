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
//  in_iphone.m
//  iPhone Quake
//
//  Todd Moore, October 2008
//

#import "in_iphone.h"
#import "EAGLView.h"
#include "quakedef.h"

static AccelerometerHandler * instance = nil;
static EAGLView * view = nil;

void IN_Init (void)
{
	instance = [[AccelerometerHandler alloc] init];
	view = [EAGLView instance];
}

void IN_Commands (void)
{
}

void IN_Shutdown (void)
{
	[instance release];
}

/* Add accelerometer inputs to the command input */
static void AccelerometerMove(usercmd_t * cmd)
{
	if ([view getUseAccelerometer] == false) return;
	
	UIAccelerationValue z = instance.z;
	UIAccelerationValue x = instance.x;
	UIAccelerationValue y = instance.y;
	
	float zMove = 0.0;
	float yMove = 0.0;
	double angle;
	if (x == 0)
	{
		angle = 0;
	}
	else
	{
		angle = fabs(atan(z/x));
		angle *= 180 / M_PI;
	}

	// 45 degrees = neutral point
	// 1000/45 = scale factor; so holding it flat is full run, holding vertical is full backstep
	// dead zone of of 10 degrees.
	if (angle > 50 || angle < 40)
	{
		zMove = (angle - 45)*(1000.0/45.0);
	}
	
	// handle side to side tilt
	// I think side to side angle is atan(y/x)
	double strafeAngle;
	if (x == 0)
	{
		strafeAngle = 0;
	}
	else
	{
		strafeAngle = atan(y/-x)*180.0/M_PI;
	}
	
	if (strafeAngle > 8 || strafeAngle < -8)
	{
		yMove = (-strafeAngle)*1000.0/45.0; // use same scale as forward/backward movement.
	}
	/*if (y <= -0.1 || y >= 0.1)
	{
		yMove = y * -1000.0;
	}*/
	
	cmd->forwardmove = zMove;
	cmd->sidemove = yMove;
}

static void KeyEvents()
{
	// process any keyboard events
	if (key_dest != key_game)
	{
		int key = [view getKey];
		if (key)
		{
			// send a up/down event for this key
			Key_Event(key, TRUE);
			Key_Event(key, FALSE);
		}
	}
}

/* examine movement of the touch, add it to the command input if there was dragging */
static void TouchEvents(usercmd_t * cmd)
{
	// touch regions for key mappings
	// +------+------+------+
	// |   2  |  3   |  4   |
	// +------+------+------+
	// |         1          |
	// +------+------+------+
	// |   5  |  6   |  7   |
	// +------+------+------+
	

	static int keyEvents[] = {//1		2			3			4			 5				6		 7			
								0,		K_ESCAPE,	K_SHIFT,	K_ENTER,	 K_CTRL,		'/',	 K_SPACE,	 // game key events
								0,		K_ESCAPE,	K_LEFTARROW, K_RIGHTARROW,	K_ENTER, K_UPARROW,	 K_DOWNARROW // menu key events
							 };

	// key offset decides what key bindings to use (game or menu)
	int keyOffset = 0;
	if (key_dest != key_game) keyOffset += 7;

	// mask represents all current button presses of the 7 regions
	static unsigned int lastMask = 0;
	static CGPoint lastLook;
	unsigned int currentMask = [view getTouchMask];
	
	// mask changed represents all buttons that have changed state since last check
	unsigned int maskChanged = lastMask ^ currentMask;
	lastMask = currentMask;
	
	// free look is our middle region
	bool freeLook = (currentMask & 1) && (key_dest == key_game); // 1st region is free look for game mode
	
	// process only when touch began or end events occur
	int button = 0;
	while (maskChanged)
	{
		if (maskChanged & 1)
		{
			bool down = currentMask & 1;
			if (button == 0) // free look button for game
			{
				// if we just pressed down then we store first position
				if (key_dest == key_game) lastLook = [view getTouchLook];
			}
			else
			{
				int key = keyEvents[button+keyOffset];
				if (key) Key_Event(key, down);
			}
		}
		maskChanged >>= 1;
		currentMask >>= 1;
		++button;
	}
	
	// process free look control
	if (freeLook)
	{
		// calculate the difference from lastlook to newlook
		CGPoint newLook = [view getTouchLook];
		CGFloat diffx = newLook.x - lastLook.x;
		CGFloat diffy = newLook.y - lastLook.y;
		lastLook = newLook;
	
		V_StopPitchDrift ();
		cl.viewangles[YAW] -= (diffy / 1.5);   // dampen to around 180 degree for up/down
		cl.viewangles[PITCH] -= (diffx / 1.1); // dampen to around 180 degree for left/right
		
		// clamp up/down look angles (don't want to backflip / tumble)
		if (cl.viewangles[PITCH] > 80) cl.viewangles[PITCH] = 80;
		if (cl.viewangles[PITCH] < -70) cl.viewangles[PITCH] = -70;
	}
}

void Sys_SendKeyEvents (void)
{
	// get any keyboard events
	KeyEvents();
	
	// get any touch events (freelook and game keys)
	TouchEvents(NULL);
}

void IN_Move (usercmd_t *cmd)
{
	AccelerometerMove(cmd);
}

@implementation AccelerometerHandler

// Implement this method to get the lastest data from the accelerometer 
- (void)accelerometer:(UIAccelerometer*)accelerometer didAccelerate:(UIAcceleration*)acceleration 
{
	x = acceleration.x;
	y = acceleration.y;
	z = acceleration.z;
	
#ifdef _DEBUG
	NSLog(@"accelerometer x=%f y=%f z=%f", acceleration.x, acceleration.y, acceleration.z);
#endif
}

-(AccelerometerHandler *) init
{
	[super init];
	
	// tm: enable accelerometer
	[[UIAccelerometer sharedAccelerometer] setUpdateInterval:(1.0 / 30)];
	[[UIAccelerometer sharedAccelerometer] setDelegate:self];
	
	x = y = z = 0;
	return self;
}

@synthesize x;
@synthesize y;
@synthesize z;
@end
