//
//  Created by Daniel Forrer on 10.08.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import "EditSharesWindowController.h"

#import "DataModel.h"
#import "FileHelper.h"
#import "Share.h"
#import "Singleton.h"


@implementation EditSharesWindowController
{
	DataModel * dataModel;
}

@synthesize shareIdTextfield;
@synthesize rootTextfield;
@synthesize passwordTextfield;
@synthesize sharesTableView;

- (id) initWithDataModel:(DataModel*) dm;
{
	self = [self initWithWindowNibName:@"EditSharesWindow"];
	if (self)
	{
		dataModel = dm;
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
	/*
	 1. Here: Create new Share-object
	 2. Notify the MainController
	 3. MainController tells GUI to refresh
	 */
	
	NSString	* shareId		= [shareIdTextfield stringValue];
	NSURL	* root		= [NSURL fileURLWithPath:[rootTextfield stringValue]];
	NSString	* passwordHash	= [FileHelper sha1OfNSString:[passwordTextfield stringValue]];
	
	Share * s = [[Share alloc] initShareWithID:shareId andRootURL:root withSecret:passwordHash];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"addShare" object:s];
}



- (IBAction) removeShare: (id)sender
{
	NSIndexSet * i = [sharesTableView selectedRowIndexes];
	long index = [i firstIndex];
	
	NSArray * mySharesArray = [[dataModel myShares] allValues];
	Share * s = [mySharesArray objectAtIndex:index];
	
	// Update StatusBar
	[[NSNotificationCenter defaultCenter] postNotificationName:@"removeShare" object:s];
}


- (IBAction) downloadShares:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"downloadSharesFromPeers" object:nil];
}


- (IBAction) printResolvedServices: (id)sender
{
	//[mc printResolvedServices];
}


- (IBAction) printShares:(id)sender
{
	//[mc printMyShares];
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
	long rv = (long)[[dataModel myShares] count];
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
		NSArray * mySharesArray = [[dataModel myShares] allValues];
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
