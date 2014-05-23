//
//  MatchOperation.m
//  Peerbox
//
//  Created by Daniel on 23.05.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import "MatchOperation.h"
#import "MainModel.h"
#import "Share.h"
#import "Peer.h"
#import "Revision.h"
#import "Constants.h"

@implementation MatchOperation
{
	MainModel * mm;
}

-(id) initWithMainModel:(MainModel*)m
{
	if ((self = [super init]))
	{
		mm = m;
	}
	return self;
}

- (void) main
{
	DebugLog(@"MainModel: MatchOperation started");
	NSMutableDictionary * myShares = [mm getAllShares];
	
	for (id key in myShares)
	{
		Share * s = [myShares objectForKey:key];
		for (Peer * p in [s allPeers])
		{
			// Match DELETE-Revisions
			//------------------------
			DebugLog(@"+++ Match DELETE-Revisions");
			
			NSArray * sortedKeys = [[[p downloadedRevsWithIsSetFalse] allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
			for (int i = (int)[sortedKeys count]-1; i>=0; i--)
			{
				DebugLog(@"---------------------");
				DebugLog(@"key: %@", key);
				DebugLog(@"---------------------");
				Revision * r = [[p downloadedRevsWithIsSetFalse] objectForKey:[sortedKeys objectAtIndex:i]];
				[r match];
				[p removeRevision:r];
			}
			
			// Match DIR-Revisions
			//---------------------
			DebugLog(@"+++ Match DIR-Revisions");
			
			sortedKeys = [[[p downloadedRevsWithIsDirTrue] allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
			for (int i = (int)[sortedKeys count]-1; i>=0; i--)
			{
				DebugLog(@"---------------------");
				DebugLog(@"key: %@", key);
				DebugLog(@"---------------------");
				Revision * r = [[p downloadedRevsWithIsDirTrue] objectForKey:[sortedKeys objectAtIndex:i]];
				[r match];
				[p removeRevision:r];
			}
			
			// Match FILE-Revisions
			//----------------------
			DebugLog(@"+++ Match FILE-Revisions");
			
			NSMutableArray * fileDownloads = [mm fileDownloads];
			
			if ([fileDownloads count] <= MAX_CONCURRENT_DOWNLOADS / 2)
			{
				NSArray * fileRevs = [p getNextFileRevisions:(int)(MAX_CONCURRENT_DOWNLOADS - [fileDownloads count])];
				for (Revision * r in fileRevs)
				{
					DebugLog(@"---------------------");
					DebugLog(@"key: %@", key);
					DebugLog(@"---------------------");
					[r setDelegate:mm];
					[fileDownloads addObject:r];
					[r match];
				}
			}
		}
	}
}


@end
