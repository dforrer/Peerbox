//
//  StatusBarController.m
//  Peerbox
//
//  Created by Daniel Forrer on 12.08.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import "StatusBarController.h"

#import "EditSharesWindowController.h"
#import "MainController.h"
#import "FileHelper.h"
#import "Share.h"
#import "Singleton.h"
#import "DataModel.h"


@implementation StatusBarController


@synthesize statusItem;
@synthesize dataModel;
@synthesize bonjourSearcher;
@synthesize timer;


- (id) initWithDataModel:(DataModel*) dm andBonjourSearcher:(BonjourSearcher *)bs
{
	if (self = [super init])
	{
		dataModel = dm;
		bonjourSearcher = bs;
		
		[self createStatusBarGUI];
		[self setTimer];
	}
	return self;
}


- (void) refreshStatusBar
{
	[self setTimer];
}


- (void) setTimer
{
	@synchronized(timer)
	{
	if ([timer isValid])
	{
		return;
	}
	//DebugLog(@"timer is not Valid");
	timer = [NSTimer timerWithTimeInterval:1.5 target:self selector:@selector(updateStatusBarMenu) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
	}
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
	[self updateStatusBarMenu];
}


- (void) updateStatusBarMenu
{
	[timer invalidate];
	timer = nil;
	
	// Get NSMenu-Pointer
	NSMenu * mymenu = [statusItem menu];
	[mymenu removeAllItems];
	
	// Allocate Default NSMenuItems
	NSMenuItem  * default_edit = [[NSMenuItem alloc ] init];
	NSMenuItem  * default_quit = [[NSMenuItem alloc ] init];
	[default_edit setTarget:self];
	
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
	
	for (id key  in [bonjourSearcher resolvedServices])
	{
		NSNetService * ns = [[bonjourSearcher resolvedServices] objectForKey:key];
		NSMenuItem * peer = [[NSMenuItem alloc ] initWithTitle:[ns hostName] action:nil keyEquivalent:@""];
		NSMenu * subItems = [[NSMenu alloc] init];
		NSMenuItem * peerID = [[NSMenuItem alloc] init];
		[subItems addItem:peerID];
		[peerID setTitle:[NSString stringWithFormat:@"PeerID: %@",[ns name]]];
		[peer setSubmenu:subItems];
		
		[mymenu insertItem:peer atIndex:0];
	}
	NSMenuItem * peersTitle = [[NSMenuItem alloc] init];
	[peersTitle setTitle:@"Peers on network:"];
	[mymenu insertItem:peersTitle atIndex:0];
	[mymenu insertItem:[NSMenuItem separatorItem] atIndex:0];

	
	// loop through myShares
	
	for (id key  in [dataModel myShares])
	{
		Share * s = [[dataModel myShares] objectForKey:key];
		NSMenuItem  * share_item = [[NSMenuItem alloc] initWithTitle:[s shareId]
												    action:@selector(openItem:)
											  keyEquivalent:@""];
		[share_item setTarget:self];
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
	
	[mymenu insertItem:[NSMenuItem separatorItem] atIndex:0];
	
	NSMenuItem  * activeDownloads = [[NSMenuItem alloc ] init];
	[activeDownloads setTitle:[NSString stringWithFormat:@"Active Downloads: %lu", [[dataModel fileDownloads] count]]];
	[mymenu insertItem:activeDownloads atIndex:0];
}


- (IBAction) openItem:(id)sender;
{
	NSString * key = [sender representedObject];
	Share * s = [[dataModel myShares] objectForKey:key];
	[[NSWorkspace sharedWorkspace] openFile:[[s root] path]];
}


- (void) openEditDialog
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"openEditDialog" object:nil];
}


@end
