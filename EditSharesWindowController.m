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


@synthesize shareIdTextfield;
@synthesize rootTextfield;
@synthesize passwordTextfield;
@synthesize sharesTableView;
@synthesize dataModel;


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
	NSLog(@"openEditDialog");
	[self showWindow:nil];
	[[self window] makeKeyAndOrderFront:self];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}


#pragma mark -----------------------
#pragma mark Interface


- (IBAction) addShare:(id)sender
{
	NSString * shareId		= [shareIdTextfield stringValue];
	NSURL    * root		= [NSURL fileURLWithPath:[rootTextfield stringValue]];
	NSString * passwordHash	= [FileHelper sha1OfNSString:[passwordTextfield stringValue]];
	
	Share * s = [[Share alloc] initShareWithID:shareId andRootURL:root withSecret:passwordHash];
	[dataModel addShare:s];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"sharesEdited" object:nil]; // Notify "MainController"
}



- (IBAction) removeShare: (id)sender
{
	NSIndexSet * i = [sharesTableView selectedRowIndexes];
	long index = [i firstIndex];
	
	NSArray * mySharesArray = [[dataModel myShares] allValues];
	Share * s = [mySharesArray objectAtIndex:index];
	[dataModel removeShare:s];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"sharesEdited" object:nil]; // Notify "MainController"
}


- (IBAction) downloadShares:(id)sender
{
	// Notify "MainController"
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
		//NSLog(@"tableView objectValueForTableColumn");
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
