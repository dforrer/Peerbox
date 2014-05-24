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
	DebugLog(@"ShareScanOperation");

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
			File * f = [share getFileForURL:u];
			[f updateIsSet];
			if (![[f isSet] boolValue])
			{
				[share setFile:f];
			}
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
			if ([[u lastPathComponent] isEqualToString:@".DS_Store"])
			{
				continue;
			}
			File * f = [share getFileForURL:u];
			if (f == nil)
			{
				f = [[File alloc] initAsNewFileWithPath:[u path]];
				if (f == nil)
				{
					//DebugLog(@"f == nil");
				}
				[share setFile:f];
				continue;
			}
			[f setUrl:u];
			[f updateIsSet];
			[f updateFileSize];
			[f updateContentModDate];
			[f updateAttributesModDate];
			if ([f isEqualToFile:[share getFileForURL:u]])
			{
				continue;
			}
			[f updateExtAttributes];
			if (![f updateVersions])
			{
				continue;
			}
			[share setFile:f];
		}
	}
}

@end
