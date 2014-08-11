//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "AppDelegate.h"

#import "Singleton.h"
#import "MainController.h"
#import "ViewController.h"

@implementation AppDelegate

@synthesize mc;
@synthesize vc;


#pragma mark -----------------------
#pragma mark NSApplicationDelegate



/**
 * What to do when app finishes loading
 */
- (void) applicationDidFinishLaunching: (NSNotification *)aNotification
{
	@autoreleasepool
	{		
		DebugLog(@"applicationDidFinishLaunching");

		mc = [[Singleton data] mainController];
		vc = [[ViewController alloc] initWithMainController:mc];
	}
}

/**
 * Terminates the App when the window is
 * closed. It does not have to be linked
 * up, in the .xib-File
 */
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)theApplication
{
	DebugLog(@"applicationShouldTerminateAfterLastWindowClosed");
	return NO;
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	return YES;
}

/**
 * What to do when app is terminated
 */
- (void) applicationWillTerminate:(NSNotification *)aNotification
{
	DebugLog(@"applicationWillTerminate");
	[mc commitAllShareDBs];
	[mc saveFileDownloads];
	[mc saveModelToPlist];
}




@end
