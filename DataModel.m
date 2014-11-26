//
//  DataModel.m
//  Peerbox
//
//  Created by Daniel Forrer on 13.08.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import "DataModel.h"
#import "DownloadFile.h"
#import "Revision.h"
#import "Peer.h"
#import "Share.h"
#import "Singleton.h"
#import "Configuration.h"

@implementation DataModel

@synthesize fileDownloads;
@synthesize myShares;

- (id) init
{
	if ((self = [super init]))
	{
		fileDownloads = [[NSMutableArray alloc] init];
		myShares = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void) saveFileDownloads
{
	for (DownloadFile * d in fileDownloads)
	{
		Revision * r = [d rev];
		[[[r peer] share] setRevision:r forPeer:[r peer]];
	}
}

/**
 * @params: addOrRemove = 1 (add) or 0 (remove)
 */
- (void) addOrRemove:(int)addOrRemove synchronizedFromFileDownloads:(DownloadFile *)d
{
	@synchronized(fileDownloads)
	{
		if (addOrRemove == 1)
		{
			[fileDownloads addObject:d];
		}
		else
		{
			[fileDownloads removeObject:d];
		}
	}
}


/**
 * Helper function for encoding the model in a readable format
 */
- (NSDictionary*) plistEncoded
{
	//NSLog(@"plistEncoded: MainModel");
	NSMutableDictionary * plist = [[NSMutableDictionary alloc] init];
	for (id key in myShares)
	{
		Share * s = [myShares objectForKey:key];
		[plist setObject:[s plistEncoded] forKey:[s shareId]];
	}
	return plist;
}


- (void) commitAllShareDBs
{
	for (Share * s in [myShares allValues])
	{
		[s dbCommit];
	}
}


#pragma mark -----------------------
#pragma mark Getter / Setter



- (BOOL) addShare:(Share*)s
{
	if (![[myShares allKeys] containsObject:[s shareId]])
	{
		[myShares setObject:s forKey:[s shareId]];
		return TRUE;
	}
	return FALSE;
}



- (void) removeShare:(Share*)s
{
	[myShares removeObjectForKey:[s shareId]];

	// Remove .sqlite-File
	NSString * sqlitePath = [NSString stringWithFormat:@"%@/%@.sqlite", [[[Singleton data] config] workingDir], [s shareId]];
	NSError * error;
	[[NSFileManager defaultManager] removeItemAtPath:sqlitePath error:&error];
}



@end
