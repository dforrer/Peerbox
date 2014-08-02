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
	MainController * mc;
}


@synthesize editWindow;
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

		mc = [[Singleton data] mainController];
		
		[self createStatusBarGUI];
		
		// Start Listening for Changes to the StatusBar
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appShouldRefreshStatusBar:) name:@"appShouldRefreshStatusBar" object:nil];
		
	}
}

- (void) appShouldRefreshStatusBar:(NSNotification*)aNotification
{
	[self updateStatusBarMenu];
}

- (void) createStatusBarGUI
{
	NSImage * menuImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"menubar_icon" ofType:@"png"]];
	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	//[statusItem setTitle:@"dd"];
	[statusItem setHighlightMode:YES];
	[statusItem setImage:menuImage];
	NSMenu * mymenu = [[NSMenu alloc] init];
	[statusItem setMenu:mymenu];
}

- (void) updateStatusBarMenu
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
	
	// NSMenu needed to group the NSMenuItems
	for (id key  in [[mc bonjourSearcher] resolvedServices])
	{
		NSNetService * ns = [[[mc bonjourSearcher] resolvedServices] objectForKey:key];
		NSMenuItem * peer = [[NSMenuItem alloc ] initWithTitle:[ns hostName] action:nil keyEquivalent:@""];
		NSMenu * subItems = [[NSMenu alloc] init];
		NSMenuItem * peerID = [[NSMenuItem alloc] init];
		[subItems addItem:peerID];
		[peerID setTitle:[ns name]];
		[peer setSubmenu:subItems];
		
		[mymenu insertItem:peer atIndex:0];
	}
	NSMenuItem * peersTitle = [[NSMenuItem alloc] init];
	[peersTitle setTitle:@"Peers available:"];
	[mymenu insertItem:peersTitle atIndex:0];
	[mymenu insertItem:[NSMenuItem separatorItem] atIndex:0];
	
	// loop through myShares
	for (id key  in [mc myShares])
	{
		Share * s = [[mc myShares] objectForKey:key];
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
	[shares_title setTitle:@"Shares being synced:"];
	[mymenu insertItem:shares_title atIndex:0];
}

- (IBAction) openItem:(id)sender;
{
	NSString * key = [sender representedObject];
	Share * s = [[mc myShares] objectForKey:key];
	[[NSWorkspace sharedWorkspace] openFile:[[s root] path]];
}

- (void) openEditDialog
{
	[editWindow makeKeyAndOrderFront:self];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
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
	[mc commitAllShareDBs];
	[mc saveModel];
}


#pragma mark -----------------------
#pragma mark Interface


- (IBAction) addShare:(id)sender
{
	NSString	* shareId		= [shareIdTextfield stringValue];
	NSURL	* root		= [NSURL fileURLWithPath:[rootTextfield stringValue]];
	NSString	* passwordHash	= [FileHelper sha1OfNSString:[passwordTextfield stringValue]];

	[mc addShareWithID:shareId andRootURL:root andPasswordHash:passwordHash];
	[mc downloadSharesFromPeers];
	
	[sharesTableView reloadData];
	
	[self updateStatusBarMenu];
}



- (IBAction) removeShare: (id)sender
{
	NSIndexSet * i = [sharesTableView selectedRowIndexes];
	long index = [i firstIndex];
	
	NSArray * mySharesArray = [[mc myShares] allValues];
	Share * shareAtIndex = [mySharesArray objectAtIndex:index];
	[mc removeShareForID:[shareAtIndex shareId]];

	[sharesTableView reloadData];

	[self updateStatusBarMenu];
}


- (IBAction) downloadShares:(id)sender
{
	[mc downloadSharesFromPeers];
}


- (IBAction) downloadRevisions:(id)sender
{
	[mc downloadRevisionsFromPeers];
}


- (IBAction) matchFiles:(id)sender
{
	[mc matchFiles];
}


- (IBAction) printResolvedServices: (id)sender
{
	[mc printResolvedServices];
}


- (IBAction) printShares:(id)sender
{
	[mc printMyShares];
}



#pragma mark -----------------------
#pragma mark NSTableViewDataSource



/**
 * OVERRIDE
 */
- (NSInteger) numberOfRowsInTableView:(NSTableView *)aTableView
{
	long rv = (long)[[mc myShares] count];
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
		NSArray * mySharesArray = [[mc myShares] allValues];
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
