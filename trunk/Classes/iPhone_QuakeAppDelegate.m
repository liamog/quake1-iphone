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
//  iPhone_QuakeAppDelegate.m
//  iPhone Quake
//
//  Kevin Arunski, October 2008 - Graphics, Network, and Sound support
//  Todd Moore, October 2008 - Multitouch Controls, Accelerometer, and Overlay Support
//  More information can be found at www.tmsoft.com
//

#import "iPhone_QuakeAppDelegate.h"
#import "EAGLView.h"
#include "quakedef.h"

static quakeparms_t    parms;

@implementation ErrorViewDelegate

- (void)alertView: (UIAlertView *) alert didDismissWithButtonIndex:(NSInteger)button
{
	exit(1);
}

-(ErrorViewDelegate *)init
{
	[super init];
	view = [[UIAlertView alloc] initWithTitle:@"Sys_Error"
							message:nil
							delegate:self
							cancelButtonTitle:@"Exit"
							otherButtonTitles:nil];
	return self;
}

-(void)showWithTitle: (NSString *)title message:(NSString *)message
{
	view.title = title;
	view.message = message;
	[view show];
}

-(void)dealloc
{
	[view release];
	[super dealloc];
}

@end

@implementation iPhone_QuakeAppDelegate

@synthesize window;
@synthesize glView;

- (iPhone_QuakeAppDelegate *)init 
{
	[super init];
	errorHandler = [[ErrorViewDelegate alloc] init];
	return self;
}

- (void)applicationDidFinishLaunching:(UIApplication *)application 
{
	
	parms.memsize = 24*1024*1024;
	parms.membase = malloc (parms.memsize);
	parms.basedir = ".";

	char * argv[] = {"quake"};
	
	COM_InitArgv (sizeof(argv)/sizeof(char *), (char **)argv);
	parms.argc = com_argc;
	parms.argv = com_argv;

	// must tell status bar our orientation so keyboard displays in landscape mode
	[application setStatusBarOrientation: UIInterfaceOrientationLandscapeRight animated: NO];
	
	@try
	{
		Host_Init (&parms);
		// accelerometer interface provides the necessary 30Hz timer on the device;
		// no need for a timer
		glView.animationInterval = 1.0 / 60.0;
		[glView startAnimation];
	}
	@catch (NSException * e)
	{
		[errorHandler showWithTitle:e.name message:e.reason];
	}
	
	// tm: stop the screen from dimming
	application.idleTimerDisabled = YES;
}


- (void)applicationWillResignActive:(UIApplication *)application 
{
	glView.animationInterval = 1.0 / 5.0;
}


- (void)applicationDidBecomeActive:(UIApplication *)application 
{
	glView.animationInterval = 1.0 / 60.0;
}


- (void)dealloc 
{
	free(parms.membase);
	[window release];
	[glView release];
	[errorHandler release];
	[super dealloc];
}

@end
