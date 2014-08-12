//
//  Created by Daniel Forrer on 10.08.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import "EditSharesWindowController.h"

#import "MainController.h"
#import "FileHelper.h"
#import "Share.h"
#import "Singleton.h"


@implementation EditSharesWindowController
{
	MainController * mc;
}

@synthesize shareIdTextfield;
@synthesize rootTextfield;
@synthesize passwordTextfield;
@synthesize sharesTableView;

- (id) initWithMainController:(MainController*) m
{
	self = [self initWithWindowNibName:@"EditSharesWindow"];
	if (self)
	{
		mc = m;
	}
	return self;
}


- (void) openEditDialog
{
	DebugLog(@"openEditDialog");
	[self showWindow:nil];
	[[self window] makeKeyAndOrderFront:self];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
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
	
	// Update StatusBar
	[[NSNotificationCenter defaultCenter] postNotificationName:@"appShouldRefreshStatusBar" object:nil];
	
}



- (IBAction) removeShare: (id)sender
{
	NSIndexSet * i = [sharesTableView selectedRowIndexes];
	long index = [i firstIndex];
	
	NSArray * mySharesArray = [[mc myShares] allValues];
	Share * shareAtIndex = [mySharesArray objectAtIndex:index];
	[mc removeShareForID:[shareAtIndex shareId]];
	
	[sharesTableView reloadData];
	
	// Update StatusBar
	[[NSNotificationCenter defaultCenter] postNotificationName:@"appShouldRefreshStatusBar" object:nil];
	
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

- (IBAction) printDebugLogs:(id)sender
{
	
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
		
		if ([[aTableColumn identifier] isEqualToString:@"Secret"])
		{
			return [shareAtIndex secret];
		}
		NSLog(@"***ERROR** dropped through pTableColumn identifiers");
		
		return NULL;
	}
}



@end
