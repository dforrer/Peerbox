//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "AppDelegate.h"

#import "Singleton.h"
#import "MainController.h"
#import "DataModel.h"

@implementation AppDelegate

@synthesize mc;

#pragma mark -----------------------
#pragma mark NSApplicationDelegate



/**
 * What to do when app finishes loading
 */
- (void) applicationDidFinishLaunching: (NSNotification *)aNotification
{
	@autoreleasepool
	{		
		NSLog(@"applicationDidFinishLaunching");

		mc = [[MainController alloc] init];
	}
}

/**
 * Terminates the App when the window is
 * closed. It does not have to be linked
 * up, in the .xib-File
 */
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)theApplication
{
	NSLog(@"applicationShouldTerminateAfterLastWindowClosed");
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
	NSLog(@"applicationWillTerminate");
	[[mc dataModel] commitAllShareDBs];
	[[mc dataModel] saveFileDownloads];
	[mc saveModelToPlist];
}




@end
