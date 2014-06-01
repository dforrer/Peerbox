//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "AppDelegate.h"

#import "FileHelper.h"
#import "Share.h"
#import "Singleton.h"
#import "MainController.h"


@implementation AppDelegate
{
	MainController * mm;
}


@synthesize window;
@synthesize shareIdTextfield;
@synthesize rootTextfield;
@synthesize passwordTextfield;
@synthesize sharesTableView;
@synthesize statusItem;



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
		mm = [[Singleton data] mainModel];
		[sharesTableView reloadData];
		
		NSImage * menuImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
						   pathForResource:@"menubar_icon" ofType:@"png"]];
		statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
		//[statusItem setTitle:@"dd"];
		[statusItem setHighlightMode:YES];
		[statusItem setImage:menuImage];
		NSMenu * mymenu = [[NSMenu alloc] init];
		[mymenu setDelegate:self];
		[statusItem setMenu:mymenu];
		[self update_menu];
	}
}


- (void) update_menu
{
	// Get NSMenu-Pointer
	NSMenu * mymenu = [statusItem menu];
	[mymenu removeAllItems];
	
	// Allocate Default NSMenuItems
	NSMenuItem  * default_edit = [[NSMenuItem alloc ] init];
	NSMenuItem  * default_quit = [[NSMenuItem alloc ] init];
	
	// Set Titles of Default-Items
	[default_edit setTitle:@"Edit Shares..."];
	[default_quit setTitle:@"Quit"];
	
	// Set Actions of Default-Items
	[default_edit setAction:@selector(openEditDialog)];
	[default_quit setAction:@selector(terminate:)];
	
	// Add NSMenuItems to myself (NSMenu)
	[mymenu addItem: [NSMenuItem separatorItem]];
	[mymenu addItem: default_edit];
	[mymenu addItem: default_quit];
	
	// loop through myShares
	for (id key  in [mm getAllShares])
	{
		Share * s = [[mm getAllShares] objectForKey:key];
		NSMenuItem  * share_item = [[NSMenuItem alloc] initWithTitle:[s shareId]
												    action:@selector(openItem:)
											  keyEquivalent:@""];
		[share_item setRepresentedObject:key];
		
		// Get and prepare icon for item
		NSImage * iconOfFile = [[NSWorkspace sharedWorkspace] iconForFile: [[s root] path]];
		NSSize smallIconSize;
		smallIconSize.height = 16;
		smallIconSize.width  = 16;
		[iconOfFile setSize:smallIconSize];
		
		[share_item setImage: iconOfFile];
		
		
		[mymenu insertItem:share_item atIndex:0];
				
	}

	NSMenuItem  * shares_title = [[NSMenuItem alloc ] init];
	[shares_title setTitle:@"Folders being synced:"];
	[mymenu insertItem:shares_title atIndex:0];
}

- (IBAction) openItem:(id)sender;
{
	NSString        *key            = [sender representedObject];
	
	Share * s = [[mm getAllShares] objectForKey:key];
	
	[[NSWorkspace sharedWorkspace] openFile:[[s root] path]];
}

- (void) openEditDialog
{
	[window makeKeyAndOrderFront:self];
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

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	return YES;
}

/**
 * What to do when app is terminated
 */
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	DebugLog(@"applicationWillTerminate");
	[mm commitAllShareDBs];
	[mm saveModel];
}


#pragma mark -----------------------
#pragma mark Interface


- (IBAction) addShare:(id)sender
{
	NSString	* shareId		= [shareIdTextfield stringValue];
	NSURL	* root		= [NSURL fileURLWithPath:[rootTextfield stringValue]];
	NSString	* passwordHash	= [FileHelper sha1OfNSString:[passwordTextfield stringValue]];

	[mm addShareWithID:shareId andRootURL:root andPasswordHash:passwordHash];
	
	[sharesTableView reloadData];
	
	[self update_menu];
}



- (IBAction) removeShare: (id)sender
{
	NSIndexSet * i = [sharesTableView selectedRowIndexes];
	long index = [i firstIndex];
	
	NSArray * mySharesArray = [[mm getAllShares] allValues];
	Share * shareAtIndex = [mySharesArray objectAtIndex:index];
	[mm removeShareForID:[shareAtIndex shareId]];

	[sharesTableView reloadData];

	[self update_menu];
}

- (IBAction) downloadShares:(id)sender
{
	[mm downloadSharesFromPeers];
}

- (IBAction) downloadRevisions:(id)sender
{
	[mm downloadRevisionsFromPeers];
}

- (IBAction) matchFiles:(id)sender
{
	[mm matchFiles];
}

- (IBAction) printResolvedServices: (id)sender
{
	[mm printResolvedServices];
}



- (IBAction) printShares:(id)sender
{
	[mm printMyShares];
}



#pragma mark -----------------------
#pragma mark NSTableViewDataSource



/**
 * OVERRIDE
 */
- (NSInteger) numberOfRowsInTableView:(NSTableView *)aTableView
{
	long rv = (long)[[mm getAllShares] count];
	return rv;
}



/**
 * OVERRIDE: Getter for NSTableView
 */
- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	@autoreleasepool
	{
		//DebugLog(@"tableView objectValueForTableColumn");
		NSArray * mySharesArray = [[mm getAllShares] allValues];
		Share * shareAtIndex = [mySharesArray objectAtIndex:rowIndex];
		if (!shareAtIndex)
		{
			NSLog(@"tableView: objectAtIndex:%ld = NULL",(long)rowIndex);
			return NULL;
		}
		
		//NSLog(@"pTableColumn identifier = %@",[aTableColumn identifier]);
		
		if ([[aTableColumn identifier] isEqualToString:@"ShareID"])
		{
			return [shareAtIndex shareId];
		}
		
		if ([[aTableColumn identifier] isEqualToString:@"Path"])
		{
			return [[shareAtIndex root] path];
		}
		NSLog(@"***ERROR** dropped through pTableColumn identifiers");
		
		return NULL;
	}
}



@end
