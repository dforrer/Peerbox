//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

#import "ShareScanOperation.h"

#import "Share.h"
#import "File.h"
#import "FileHelper.h"

@implementation ShareScanOperation

@synthesize share;



- (id)initWithShare: (Share*) s
{
	if ( self = [super init] )
	{
		share = s;
	}
	return self;
}



/**
 * Diese methode muss bei Subklassen von NSOperation überschrieben werden!
 */
- (void) main
{
//DebugLog(@"ShareScanOperation");

	// Search DELETED Files
	//----------------------
	NSArray * urlsAsStrings = [share getURLsBelowURL:[share root]
								    withIsSet:TRUE];
	for (int i = 0; i < [urlsAsStrings count]; i++)
	{
		@autoreleasepool
		{
			if ([self isCancelled])
			{
				return;
			}
			NSURL * u = [NSURL URLWithString:urlsAsStrings[i][0]];

			[share scanURL:u recursive:NO];
		}
	}
	
	// Search ADDED/CHANGED Files
	//---------------------------
	NSArray * dirTree = [FileHelper scanDirectoryRecursive:[share root]];
	for (NSURL * u in dirTree)
	{
		@autoreleasepool
		{
			if ([self isCancelled])
			{
				return;
			}
			[share scanURL:u recursive:NO];
		}
	}
}

@end
