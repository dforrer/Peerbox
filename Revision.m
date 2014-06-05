//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

#import "Revision.h"

#import "Share.h"
#import "Peer.h"
#import "File.h"
#import "FileHelper.h"


@implementation Revision
{

}


@synthesize relURL;
@synthesize revision;
@synthesize isSet;
@synthesize extAttributes;
@synthesize versions;
@synthesize peer;
@synthesize lastMatchAttempt;
@synthesize isDir;
@synthesize fileSize;
@synthesize isSymlink;
@synthesize targetPath;

- (BOOL) isZeroLengthFile
{
	return [fileSize longLongValue] == 0;
}

/**
 * Helper-Function equal to File-Class
 */
- (NSString *) getLastVersionHash
{
	return [versions objectForKey:[self getLastVersionKey]];
}

/**
 * Helper-Function equal to File-Class
 */
- (NSString *) getLastVersionKey
{
	NSArray * local = [[[self versions] allKeys] sortedArrayUsingComparator:^(NSString *str1, NSString *str2) {
		return [str1 compare:str2 options:NSNumericSearch];
	}];;
	return [local lastObject];
}


- (void) updateLastMatchAttempt
{
	lastMatchAttempt = [NSDate date];
}


- (BOOL) canBeMatchedInstantly
{
	if ([isDir boolValue] == TRUE)
	{
		return TRUE;
	}
	else if ([isSet boolValue] == FALSE)
	{
		return TRUE;
	}
	else if ([isDir boolValue] == FALSE && [self isZeroLengthFile] == TRUE)
	{
		return TRUE;
	}
	else if ([isSymlink boolValue] == TRUE)
	{
		return TRUE;
	}
	return FALSE;
}


@end
