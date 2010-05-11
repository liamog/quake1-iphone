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
//  iPhone_QuakeAppDelegate.h
//  iPhone Quake
//
//  Kevin Arunski, October 2008 - Graphics, Network, and Sound support
//  Todd Moore, October 2008 - Multitouch Controls, Accelerometer, and Overlay Support
//  More information can be found at www.tmsoft.com
//

#import <UIKit/UIKit.h>
#import <UIKit/UIAlert.h>

@interface ErrorViewDelegate : NSObject<UIAlertViewDelegate> {
	UIAlertView * view;
}

-(void)showWithTitle:(NSString *)title message:(NSString *)message;

@end

@class EAGLView;

@interface iPhone_QuakeAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    EAGLView *glView;
	ErrorViewDelegate *errorHandler;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet EAGLView *glView;

@end
